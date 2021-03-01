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
        .PARAMETER PartialMgDiscovery
            Enable partial management group discovery.
            Necessary if current user does not have root access.
            Must be used in combination with -PartialMgDiscoveryRoot
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

        [switch]
        $PartialMgDiscovery = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot'),

        [string[]]
        $PartialMgDiscoveryRoot = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot')
    )

    begin {
        Assert-AzOpsWindowsLongPath -Cmdlet $PSCmdlet
        Assert-AzOpsJQDepedency

        $allAzContext = Get-AzContext -ListAvailable
        if (-not $allAzContext) {
            Stop-PSFFunction -String 'Initialize-AzOpsEnvironment.AzureContext.No' -EnableException $true -Cmdlet $PSCmdlet
        }
        $azContextTenants = @($AllAzContext.Tenant.Id | Sort-Object -Unique)
        if (-not $IgnoreContextCheck -and $azContextTenants.Count -gt 1) {
            Stop-PSFFunction -String 'Initialize-AzOpsEnvironment.AzureContext.TooMany' -StringValues $azContextTenants.Count, ($azContextTenants -join ',') -EnableException $true -Cmdlet $PSCmdlet
        }
    }

    process {
        # If data exists and we don't want to rebuild the data cache, no point in continuing
        if (-not $InvalidateCache -and $script:AzOpsAzManagementGroup -and $script:AzOpsSubscriptions) {
            Write-PSFMessage -String 'Initialize-AzOpsEnvironment.UsingCache'
            return
        }

        #region Initialize & Prepare
        Write-PSFMessage -String 'Initialize-AzOpsEnvironment.Processing'
        $currentAzContext = Get-AzContext
        $tenantId = $currentAzContext.Tenant.Id
        $rootScope = '/providers/Microsoft.Management/managementGroups/{0}' -f $tenantId

        Write-PSFMessage -String 'Initialize-AzOpsEnvironment.Initializing'
        if (-not (Test-Path -Path (Get-PSFConfigValue -FullName 'AzOps.Core.State'))) {
            $null = New-Item -path (Get-PSFConfigValue -FullName 'AzOps.Core.State') -Force -ItemType directory
        }
        $script:AzOpsSubscriptions = Get-AzOpsSubscription -ExcludedOffers $ExcludedSubOffer -ExcludedStates $ExcludedSubState -TenantId $tenantId
        $script:AzOpsAzManagementGroup = @()
        $script:AzOpsPartialRoot = @()
        #endregion Initialize & Prepare

        #region Management Group Processing
        $managementGroups = Get-AzManagementGroup -ErrorAction Stop
        if ($rootScope -notin $managementGroups.Id -and -not $PartialMgDiscovery) {
            Write-PSFMessage -Level Warning -String 'Initialize-AzOpsEnvironment.ManagementGroup.NotFound' -StringValues $rootScope, (Get-AzContext).Account.Id -Tag Error
            return
        }

        #region Validate root '/' permissions
        if ($currentAzContext.Account.Type -eq "User") {
            $rootPermissions = Get-AzRoleAssignment -UserPrincipalName $currentAzContext.Account.Id -Scope "/" -ErrorAction SilentlyContinue
        }
        else {
            $rootPermissions = Get-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -ApplicationId $currentAzContext.Account.Id).Id -Scope "/" -ErrorAction SilentlyContinue
        }
        if (-not $rootPermissions) {
            Write-PSFMessage -Level Warning -String 'Initialize-AzOpsEnvironment.ManagementGroup.NoRootPermissions' -StringValues $currentAzContext.Account.Id
            $PartialMgDiscovery = $true
        }
        #endregion Validate root '/' permissions

        #region Partial Discovery
        if ($PartialMgDiscovery -and $PartialMgDiscoveryRoot) {
            Write-PSFMessage -Level Warning -String 'Initialize-AzOpsEnvironment.ManagementGroup.PartialDiscovery'
            $managementGroups = @()
            foreach ($managementRoot in $PartialMgDiscoveryRoot) {
                $managementGroups += [pscustomobject]@{ Name = $managementRoot }
                $script:AzOpsPartialRoot += Get-AzManagementGroup -GroupId $managementRoot -Recurse -Expand -WarningAction SilentlyContinue
            }
        }
        #endregion Partial Discovery

        #region Management Group Resolution
        Write-PSFMessage -String 'Initialize-AzOpsEnvironment.ManagementGroup.Resolution' -StringValues $managementGroups.Count
        $tempResolved = foreach ($mgmtGroup in $managementGroups) {
            Write-PSFMessage -String 'Initialize-AzOpsEnvironment.ManagementGroup.Expanding' -StringValues $mgmtGroup.Name
            Get-AzOpsManagementGroups -ManagementGroup $mgmtGroup.Name -PartialDiscovery:$PartialMgDiscovery
        }

        $script:AzOpsAzManagementGroup = $tempResolved | Sort-Object -Property Id -Unique
        #endregion Management Group Resolution
        #endregion Management Group Processing

        Write-PSFMessage -String 'Initialize-AzOpsEnvironment.Processing.Completed'
    }

}