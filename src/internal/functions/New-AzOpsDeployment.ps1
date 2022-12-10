function New-AzOpsDeployment {

    <#
        .SYNOPSIS
            Deploys a full state into azure.
        .DESCRIPTION
            Deploys a full state into azure.
        .PARAMETER DeploymentName
            Name under which to deploy the state.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the parameters of the ARM templates can be found.
        .PARAMETER Mode
            Mode in which to process the templates.
            Defaults to incremental.
        .PARAMETER StatePath
            The root folder under which to find the resource json.
        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > $AzOpsDeploymentList | Select-Object $uniqueProperties -Unique | Sort-Object -Property TemplateParameterFilePath | New-Deployment
            Deploy all unique deployments provided from $AzOpsDeploymentList
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $DeploymentName = "azops-template-deployment",

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateFilePath = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate'),

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]
        $TemplateParameterFilePath,

        [string]
        $Mode = "Incremental",

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [string[]]
        $WhatifExcludedChangeTypes = (Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes')

    )

    process {
        Write-PSFMessage -Level Important -String 'New-AzOpsDeployment.Processing' -StringValues $DeploymentName, $TemplateFilePath, $TemplateParameterFilePath, $Mode -Target $TemplateFilePath

        #region Resolve Scope
        try {
            if ($TemplateParameterFilePath) {
                $scopeObject = New-AzOpsScope -Path $TemplateParameterFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
            }
            else {
                $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
            }
            $scopeFound = $true
        }
        catch {
            Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.Scope.Failed' -Target $TemplateFilePath -StringValues $TemplateFilePath, $TemplateParameterFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.Scope.Empty' -Target $TemplateFilePath -StringValues $TemplateFilePath, $TemplateParameterFilePath
            return
        }
        #endregion Resolve Scope

        #region Parse Content
        $templateContent = Get-Content $TemplateFilePath | ConvertFrom-Json -AsHashtable

        if ($templateContent.metadata._generator.name -eq 'bicep') {
            # Detect bicep templates
            $bicepTemplate = $true
        }
        #endregion

        #region Process Scope
        # Configure variables/parameters and the WhatIf/Deployment cmdlets to be used per scope
        $defaultDeploymentRegion = (Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')
        $parameters = @{
            'TemplateFile'                = $TemplateFilePath
            'SkipTemplateParameterPrompt' = $true
            'Location'                    = $defaultDeploymentRegion
        }
        # Resource Groups excluding Microsoft.Resources/resourceGroups that needs to be submitted at subscription scope
        if ($scopeObject.resourcegroup -and $templateContent.resources[0].type -ne 'Microsoft.Resources/resourceGroups') {
            Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.ResourceGroup.Processing' -StringValues $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            $whatIfCommand = 'Get-AzResourceGroupDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzResourceGroupDeployment'
            $parameters.ResourceGroupName = $scopeObject.resourcegroup
            $parameters.Remove('Location')
        }
        # Subscriptions
        elseif ($scopeObject.subscription) {
            Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.Subscription.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            $whatIfCommand = 'Get-AzSubscriptionDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzSubscriptionDeployment'
        }
        # Management Groups
        elseif ($scopeObject.managementGroup -and (-not ($scopeObject.StatePath).StartsWith('azopsscope-assume-new-resource_'))) {
            Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.ManagementGroup.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            $parameters.ManagementGroupId = $scopeObject.managementgroup
            $whatIfCommand = 'Get-AzManagementGroupDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzManagementGroupDeployment'
        }
        # Tenant deployments
        elseif ($scopeObject.type -eq 'root' -and $scopeObject.scope -eq '/') {
            Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.Root.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            $whatIfCommand = 'Get-AzTenantDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzTenantDeployment'
        }
        # If Management Group resource was not found, validate and prepare for first time deployment of resource
        elseif (($scopeObject.StatePath).StartsWith('azopsscope-assume-new-resource_')) {
            $resourceScopeFileContent = Get-Content -Path $addition | ConvertFrom-Json -Depth 100
            $resource = ($resourceScopeFileContent.resources | Where-Object {$_.type -eq 'Microsoft.Management/managementGroups'} | Select-Object -First 1)
            $pathDir = (Get-Item -Path $addition).Directory | Resolve-Path -Relative
            if ((Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath') -ne '.') {
                $pathDir = Split-Path -Path $pathDir -Parent
            }
            $parentDirScopeObject = New-AzOpsScope -Path (Split-Path -Path $pathDir -Parent) -WhatIf:$false | Where-Object {(-not ($_.StatePath).StartsWith('azopsscope-assume-new-resource_'))}
            $parentIdScope = New-AzOpsScope -Scope (($resource).properties.details.parent.id) -WhatIf:$false | Where-Object {(-not ($_.StatePath).StartsWith('azopsscope-assume-new-resource_'))}
            # Validate parent existence with content parent scope, statepath and name match, determines file location match deployment scope
            if ($parentDirScopeObject -and $parentIdScope -and $parentDirScopeObject.Scope -eq $parentIdScope.Scope -and $parentDirScopeObject.StatePath -eq $parentIdScope.StatePath -and $parentDirScopeObject.Name -eq $parentIdScope.Name) {
                # Validate directory name match resource information
                if ((Get-Item -Path $pathDir).Name -eq "$($resource.properties.displayName) ($($resource.name))") {
                    Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.Root.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
                    $whatIfCommand = 'Get-AzTenantDeploymentWhatIfResult'
                    $deploymentCommand = 'New-AzTenantDeployment'
                }
                # Invalid directory name
                else {
                    Write-PSFMessage -Level Error -String 'New-AzOpsDeployment.Directory.NotFound' -Target $scopeObject -Tag Error -StringValues (Get-Item -Path $pathDir).Name, "$($resource.properties.displayName) ($($resource.name))"
                    throw
                }
            }
            # Parent missing
            else {
                Write-PSFMessage -Level Error -String 'New-AzOpsDeployment.Parent.NotFound' -Target $scopeObject -Tag Error -StringValues $addition
                throw
            }
        }
        else {
            Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.Scope.Unidentified' -Target $scopeObject -StringValues $scopeObject
            $scopeFound = $false
        }
        # Proceed with WhatIf or Deployment if scope was found
        if ($scopeFound) {
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            if ($WhatifExcludedChangeTypes) {
                $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
            }
            # Get predictive deployment results from WhatIf API
            $results = & $whatIfCommand @parameters -ErrorAction Continue -ErrorVariable resultsError
            if ($resultsError) {
                $resultsErrorMessage = $resultsError.exception.InnerException.Message
                # Ignore errors for bicep modules
                if ($resultsErrorMessage -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                    $invalidTemplate = $true
                }
                # Handle WhatIf prediction errors
                elseif ($resultsErrorMessage -match 'DeploymentWhatIfResourceError' -and $resultsErrorMessage -match "The request to predict template deployment") {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsErrorMessage
                    Set-AzOpsWhatIfOutput -FilePath $parameters.TemplateFile -Results ('{0}WhatIf prediction failed with error - validate changes manually before merging:{0}{1}' -f [environment]::NewLine, $resultsErrorMessage)
                }
                else {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsErrorMessage
                    throw $resultsErrorMessage
                }
            }
            elseif ($results.Error) {
                Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            else {
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -FilePath $parameters.TemplateFile -Results $results
            }
            # Remove ExcludeChangeType parameter as it doesn't exist for deployment cmdlets
            if ($parameters.ExcludeChangeType) {
                $parameters.Remove('ExcludeChangeType')
            }
            $parameters.Name = $DeploymentName
            if ($PSCmdlet.ShouldProcess("Start $($scopeObject.type) Deployment with $deploymentCommand?")) {
                if (-not $invalidTemplate) {
                    & $deploymentCommand @parameters
                }
            }
            else {
                # Exit deployment
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
    }
}