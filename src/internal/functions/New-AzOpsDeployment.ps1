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
        .PARAMETER TemplateObject
            TemplateObject where the templates content is stored in-memory.
        .PARAMETER TemplateParameterFilePath
            Path where the parameters of the ARM templates can be found.
        .PARAMETER Mode
            Mode in which to process the templates.
            Defaults to incremental.
        .PARAMETER StatePath
            The root folder under which to find the resource json.
        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
        .PARAMETER WhatifExcludedChangeTypes
            Exclude specific change types from WhatIf operations.
        .PARAMETER WhatIfResultFormat
            Accepts ResourceIdOnly or FullResourcePayloads.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > $AzOpsDeploymentList | Select-Object $uniqueProperties -Unique | Sort-Object -Property TemplateParameterFilePath | New-Deployment
            Deploy all unique deployments provided from $AzOpsDeploymentList
            Name                           Value
            ----                           -----
            filePath                       /root/managementgroup/subscription/resourcegroup/template.json
            parameterFilePath              /root/managementgroup/subscription/resourcegroup/template.parameters.json
            results                        Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.Deployments.PSWhatIfOperationResult
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
        [hashtable]
        $TemplateObject,

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
        $WhatifExcludedChangeTypes = (Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'),

        [string]
        [ValidateSet("ResourceIdOnly","FullResourcePayloads")]
        $WhatIfResultFormat

    )

    process {
        Write-AzOpsMessage -LogLevel Important -LogString 'New-AzOpsDeployment.Processing' -LogStringValues $DeploymentName, $TemplateFilePath, $TemplateParameterFilePath, $Mode -Target $TemplateFilePath

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
            Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.Scope.Failed' -LogStringValues $TemplateFilePath, $TemplateParameterFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.Scope.Empty' -LogStringValues $TemplateFilePath, $TemplateParameterFilePath
            return
        }
        #endregion Resolve Scope

        #region Parse Content
        if ($null -eq $TemplateObject) {
            $TemplateFileContent = [System.IO.File]::ReadAllText($TemplateFilePath)
            $TemplateObject = ConvertFrom-Json $TemplateFileContent -AsHashtable
        }
        if ($TemplateObject.metadata._generator.name -eq 'bicep') {
            # Detect bicep templates
            $bicepTemplate = $true
        }
        #endregion

        #region Process Scope
        # Configure variables/parameters and the WhatIf/Deployment cmdlets to be used per scope
        $defaultDeploymentRegion = (Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')
        $parameters = @{
            'TemplateObject'              = $TemplateObject
            'SkipTemplateParameterPrompt' = $true
            'Location'                    = $defaultDeploymentRegion
        }
        if ($WhatIfResultFormat) {
            $parameters.ResultFormat = $WhatIfResultFormat
        }
        # Resource Groups excluding Microsoft.Resources/resourceGroups that needs to be submitted at subscription scope
        if ($scopeObject.resourcegroup -and $TemplateObject.resources[0].type -ne 'Microsoft.Resources/resourceGroups') {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.ResourceGroup.Processing' -LogStringValues $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            $whatIfCommand = 'Get-AzResourceGroupDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzResourceGroupDeployment'
            $parameters.ResourceGroupName = $scopeObject.resourcegroup
            $parameters.Remove('Location')
        }
        # Subscriptions
        elseif ($scopeObject.subscription) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.Subscription.Processing' -LogStringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            $whatIfCommand = 'Get-AzSubscriptionDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzDeployment'
        }
        # Management Groups
        elseif ($scopeObject.managementGroup -and (-not ($scopeObject.StatePath).StartsWith('azopsscope-assume-new-resource_'))) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.ManagementGroup.Processing' -LogStringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            $parameters.ManagementGroupId = $scopeObject.managementgroup
            $whatIfCommand = 'Get-AzManagementGroupDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzManagementGroupDeployment'
        }
        # Tenant deployments
        elseif ($scopeObject.type -eq 'root' -and $scopeObject.scope -eq '/') {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.Root.Processing' -LogStringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            $whatIfCommand = 'Get-AzTenantDeploymentWhatIfResult'
            $deploymentCommand = 'New-AzTenantDeployment'
        }
        # If Management Group resource was not found, validate and prepare for first time deployment of resource
        elseif ($scopeObject.managementGroup -and (($scopeObject.StatePath).StartsWith('azopsscope-assume-new-resource_'))) {
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
                    Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.Root.Processing' -LogStringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
                    $whatIfCommand = 'Get-AzTenantDeploymentWhatIfResult'
                    $deploymentCommand = 'New-AzTenantDeployment'
                }
                # Invalid directory name
                else {
                    Write-AzOpsMessage -LogLevel Error -LogString 'New-AzOpsDeployment.Directory.NotFound' -LogStringValues (Get-Item -Path $pathDir).Name, "$($resource.properties.displayName) ($($resource.name))"
                    throw
                }
            }
            # Parent missing
            else {
                Write-AzOpsMessage -LogLevel Error -LogString 'New-AzOpsDeployment.Parent.NotFound' -LogStringValues $addition
                throw
            }
        }
        else {
            Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.Scope.Unidentified' -LogStringValues $scopeObject
            $scopeFound = $false
        }
        # Proceed with WhatIf or Deployment if scope was found
        if ($scopeFound) {
            $deploymentResult = [PSCustomObject]@{
                filePath    = ''
                parameterFilePath = ''
                results = ''
                deployment = ''
            }
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
                    Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                    $invalidTemplate = $true
                }
                # Handle WhatIf prediction errors
                elseif ($resultsErrorMessage -match 'DeploymentWhatIfResourceError' -and $resultsErrorMessage -match "The request to predict template deployment") {
                    Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.WhatIfWarning' -LogStringValues $resultsErrorMessage -Target $scopeObject
                    if ($parameters.TemplateParameterFile) {
                        $deploymentResult.filePath = $parameters.TemplateFile
                        $deploymentResult.parameterFilePath = $parameters.TemplateParameterFile
                        $deploymentResult.results = ('{0}WhatIf prediction failed with error - validate changes manually before merging:{0}{1}' -f [environment]::NewLine, $resultsErrorMessage)
                    }
                    else {
                        $deploymentResult.filePath = $parameters.TemplateFile
                        $deploymentResult.results = ('{0}WhatIf prediction failed with error - validate changes manually before merging:{0}{1}' -f [environment]::NewLine, $resultsErrorMessage)
                    }
                }
                else {
                    Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.WhatIfWarning' -LogStringValues $resultsErrorMessage -Target $scopeObject
                    throw $resultsErrorMessage
                }
            }
            elseif ($results.Error) {
                Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsDeployment.TemplateError' -LogStringValues $TemplateFilePath -Target $scopeObject
                return
            }
            else {
                Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsDeployment.WhatIfResults' -LogStringValues ($results | Out-String) -Target $scopeObject
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                if ($parameters.TemplateParameterFile) {
                    $deploymentResult.filePath = $TemplateFilePath
                    $deploymentResult.parameterFilePath = $parameters.TemplateParameterFile
                    $deploymentResult.results = $results
                }
                else {
                    $deploymentResult.filePath = $TemplateFilePath
                    $deploymentResult.results = $results
                }
            }
            # Remove ExcludeChangeType parameter as it doesn't exist for deployment cmdlets
            if ($parameters.ExcludeChangeType) {
                $parameters.Remove('ExcludeChangeType')
            }
            $parameters.Name = $DeploymentName
            if ($PSCmdlet.ShouldProcess("Start $($scopeObject.type) Deployment with $deploymentCommand?")) {
                if (-not $invalidTemplate) {
                    $deploymentResult.deployment = & $deploymentCommand @parameters
                }
            }
            else {
                # Exit deployment
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'New-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #Return
        if ($deploymentResult) {
            return $deploymentResult
        }
    }
}