function Initialize-AzOpsEnvironment {

    <#
        .SYNOPSIS
            Initializes the execution context of the module.
        .DESCRIPTION
            Initializes the execution context of the module.
            This is used by all other commands.
            It prepares / caches tenant, subscription and management group data.
        .PARAMETER IgnoreContextCheck
            Whether it should validate the azure contexts available or not.
        .PARAMETER InvalidateCache
            If data was already cached from a previous execution, execute again anyway?
        .PARAMETER ExcludedSubOffer
            Subscription filter.
            Subscriptions from the listed offerings will be ignored.
            Generally used to prevent using trial subscriptions, but can be adapted for other limitations.
        .PARAMETER ExcludedSubState
            Subscription filter.
            Subscriptions in the listed states will be ignored.
            For example, by default, disabled subscriptions will not be processed.
        .PARAMETER PartialMgDiscoveryRoot
            Custom search roots under which to detect management groups.
            Used for partial management group discovery.
            Must be used in combination with -PartialMgDiscovery
        .EXAMPLE
            > Initialize-AzOpsEnvironment
            Initializes the default execution context of the module.
    #>

    [CmdletBinding()]
    param (
        [switch]
        $IgnoreContextCheck = (Get-PSFConfigValue -FullName 'AzOps.Core.IgnoreContextCheck'),

        [switch]
        $InvalidateCache = (Get-PSFConfigValue -FullName 'AzOps.Core.InvalidateCache'),

        [string[]]
        $ExcludedSubOffer = (Get-PSFConfigValue -FullName 'AzOps.Core.ExcludedSubOffer'),

        [string[]]
        $ExcludedSubState = (Get-PSFConfigValue -FullName 'AzOps.Core.ExcludedSubState'),

        [string[]]
        $PartialMgDiscoveryRoot = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot')
    )

    begin {
        # Change PSSStyle output rendering to Host to remove escape sequences are removed in redirected or piped output.
        $PSStyle.OutputRendering = [System.Management.Automation.OutputRendering]::Host
        # Assert dependencies
        Assert-AzOpsWindowsLongPath -Cmdlet $PSCmdlet
        Assert-AzOpsJqDependency -Cmdlet $PSCmdlet

        $allAzContext = Get-AzContext -ListAvailable
        if (-not $allAzContext) {
            Stop-PSFFunction -String 'Initialize-AzOpsEnvironment.AzureContext.No' -EnableException $true -Cmdlet $PSCmdlet
        }
        $azContextTenants = @($AllAzContext.Tenant.Id | Sort-Object -Unique)
        if (-not $IgnoreContextCheck -and $azContextTenants.Count -gt 1) {
            Stop-PSFFunction -String 'Initialize-AzOpsEnvironment.AzureContext.TooMany' -StringValues $azContextTenants.Count, ($azContextTenants -join ',') -EnableException $true -Cmdlet $PSCmdlet
        }

        # Adjust MultipleTemplateParameterFileSuffix if incorrect MultipleTemplateParameterFileSuffix is set and log warning
        if (-not $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').StartsWith('.')) {
            $updateMultipleTemplateParameterFileSuffix = ".$(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix')"
            Write-AzOpsMessage -LogLevel Warning -LogString 'Initialize-AzOpsEnvironment.MultipleTemplateParameterFileSuffix.Adjustment' -LogStringValues (Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix'), $updateMultipleTemplateParameterFileSuffix
            Set-PSFConfig -Module AzOps -Name Core.MultipleTemplateParameterFileSuffix -Value $updateMultipleTemplateParameterFileSuffix
        }

        # Adjust ThrottleLimit from previously default 10 to 5 if system has less than 2 cores
        [int]$cpuCores = if ($IsWindows) { $env:NUMBER_OF_PROCESSORS } else { Invoke-AzOpsNativeCommand -ScriptBlock { nproc --all } -IgnoreExitcode }
        $throttleLimit = (Get-PSFConfig -Module AzOps -Name Core.ThrottleLimit).Value
        if (-not[string]::IsNullOrEmpty($cpuCores) -and $cpuCores -le 2 -and $throttleLimit -gt 5) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Initialize-AzOpsEnvironment.ThrottleLimit.Adjustment' -LogStringValues $throttleLimit, $cpuCores
            Set-PSFConfig -Module AzOps -Name Core.ThrottleLimit -Value 5
        }

        # Validate optional custom path for custom jq template
        if ((Get-PSFConfig -Module AzOps -Name Core.SkipCustomJqTemplate).Value) {
            Write-AzOpsMessage -LogLevel Debug -LogString 'Initialize-AzOpsEnvironment.SkipCustomJqTemplate.True'
        }
        else {
            $customJqTemplatePath = (Get-PSFConfig -Module AzOps -Name Core.CustomJqTemplatePath).Value
            if (Test-Path -Path $customJqTemplatePath) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Initialize-AzOpsEnvironment.CustomJqTemplatePath' -LogStringValues $customJqTemplatePath
            }
            else {
                Write-AzOpsMessage -LogLevel Warning -LogString 'Initialize-AzOpsEnvironment.CustomJqTemplatePath.PathNotFound' -LogStringValues $customJqTemplatePath
                Set-PSFConfig -Module AzOps -Name Core.SkipCustomJqTemplate -Value $true
            }
        }
    }

    process {
        # If data exists and we don't want to rebuild the data cache, no point in continuing
        if (-not $InvalidateCache -and $script:AzOpsAzManagementGroup -and $script:AzOpsSubscriptions) {
            Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.UsingCache'
            return
        }

        #region Initialize & Prepare
        Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.Processing'
        $currentAzContext = Get-AzContext
        $tenantId = $currentAzContext.Tenant.Id
        Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.Initializing'
        if (-not (Test-Path -Path (Get-PSFConfigValue -FullName 'AzOps.Core.State'))) {
            $null = New-Item -path (Get-PSFConfigValue -FullName 'AzOps.Core.State') -Force -ItemType directory
        }
        $script:AzOpsSubscriptions = Get-AzOpsSubscription -ExcludedOffers $ExcludedSubOffer -ExcludedStates $ExcludedSubState -TenantId $tenantId
        $script:AzOpsResourceProvider = Get-AzResourceProvider -ListAvailable
        $script:AzOpsAzManagementGroup = @()
        $script:AzOpsPartialRoot = @()
        #endregion Initialize & Prepare

        #region Management Group Processing
        try {
            $managementGroups = Get-AzManagementGroup -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Initialize-AzOpsEnvironment.ManagementGroup.NoManagementGroupAccess'
            return
        }

        #region Validate root '/' permissions - different methods of getting current context depending on principalType
        try {
            $currentPrincipal = Get-AzOpsCurrentPrincipal -AzContext $currentAzContext -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Initialize-AzOpsEnvironment.CurrentPrincipal.Fail' -LogStringValues $_
        }
        if ($currentPrincipal.id) {
            try {
                $rootPermissions = Get-AzRoleAssignment -ObjectId $currentPrincipal.id -Scope "/" -ErrorAction -ErrorAction Stop
            }
            catch {
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Initialize-AzOpsEnvironment.CurrentPrincipal.RoleAssignmentFail' -LogStringValues $_
            }
        }

        if (-not $rootPermissions) {
            Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.ManagementGroup.NoRootPermissions' -LogStringValues $currentAzContext.Account.Id
            $PartialMgDiscovery = $true
        }
        else {
            $PartialMgDiscovery = $false
        }
        #endregion Validate root '/' permissions

        #region Partial Discovery
        if ($PartialMgDiscoveryRoot) {
            Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.ManagementGroup.PartialDiscovery'
            $PartialMgDiscovery = $true
            $managementGroups = @()
            foreach ($managementRoot in $PartialMgDiscoveryRoot) {
                $managementGroups += [PSCustomObject]@{ Name = $managementRoot }
                $script:AzOpsPartialRoot += Get-AzManagementGroup -GroupId $managementRoot -Recurse -Expand -WarningAction SilentlyContinue
            }
        }
        #endregion Partial Discovery

        #region Management Group Resolution
        Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.ManagementGroup.Resolution' -LogStringValues $managementGroups.Count -Metric $managementGroups.Count -MetricName 'ManagementGroup Count'
        $tempResolved = foreach ($mgmtGroup in $managementGroups) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Initialize-AzOpsEnvironment.ManagementGroup.Expanding' -LogStringValues $mgmtGroup.Name
            Get-AzOpsManagementGroup -ManagementGroup $mgmtGroup.Name -PartialDiscovery:$PartialMgDiscovery
        }
        $script:AzOpsAzManagementGroup = $tempResolved | Sort-Object -Property Id -Unique
        #endregion Management Group Resolution
        #endregion Management Group Processing
        Write-AzOpsMessage -LogLevel Important -LogString 'Initialize-AzOpsEnvironment.Processing.Completed'
        Clear-PSFMessage
    }

}