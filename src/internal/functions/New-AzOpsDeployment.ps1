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
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    process {
        Write-PSFMessage -String 'New-AzOpsDeployment.Processing' -StringValues $DeploymentName, $TemplateFilePath, $TemplateParameterFilePath, $Mode -Target $TemplateFilePath

        #region Resolve Scope
        try {
            if ($TemplateParameterFilePath) {
                $scopeObject = New-AzOpsScope -Path $TemplateParameterFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
            }
            else {
                $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
            }
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
        #region Resource Group
        if ($scopeObject.resourcegroup) {
            Set-AzOpsContext -ScopeObject $scopeObject
            if ($templateContent.resources[0].type -eq 'Microsoft.Resources/resourceGroups') {
                # Since this is a deployment for resource group, it must be invoked at subscription scope
                $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
                Write-PSFMessage -String 'New-AzOpsDeployment.Subscription.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject

                $parameters = @{
                    'TemplateFile'                = $TemplateFilePath
                    'Location'                    = $defaultDeploymentRegion
                    'SkipTemplateParameterPrompt' = $true
                }
                if ($TemplateParameterFilePath) {
                    $parameters.TemplateParameterFile = $TemplateParameterFilePath
                }

                if ((Get-AzContext).Subscription.Id -ne $scopeObject.subscription) {
                    Set-AzOpsContext -ScopeObject $scopeObject
                }
                $WhatifExcludedChangeTypes = Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'
                if($WhatifExcludedChangeTypes){
                    $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
                }
                # Validate Template
                $results = Get-AzSubscriptionDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
                if($parameters.ExcludeChangeType){$parameters.Remove('ExcludeChangeType')}
                if ($resultsError) {
                    if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
                        Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                        $invalidTemplate = $true
                    }
                    else {
                        Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsError.exception.InnerException.Message
                        throw $resultsError.exception.InnerException.Message
                    }

                }
                elseif ($results.Error) {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                    return
                }
                else {
                    Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                    Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                    Set-AzOpsWhatIfOutput -Results $results
                }

                $parameters.Name = $DeploymentName
                if ($PSCmdlet.ShouldProcess("Start Subscription Deployment?")) {
                    if (-not $invalidTemplate) {
                        New-AzSubscriptionDeployment @parameters
                    }
                }
                else {
                    # Exit deployment
                    Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
                }
            }
            else {
                Write-PSFMessage -String 'New-AzOpsDeployment.ResourceGroup.Processing' -StringValues $scopeObject -Target $scopeObject

                $parameters = @{
                    'TemplateFile'                = $TemplateFilePath
                    'SkipTemplateParameterPrompt' = $true
                    'ResourceGroupName'           = $scopeObject.resourcegroup
                }
                if ($TemplateParameterFilePath) {
                    $parameters.TemplateParameterFile = $TemplateParameterFilePath
                }
                $WhatifExcludedChangeTypes = Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'
                if($WhatifExcludedChangeTypes){
                    $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
                }
                $results = Get-AzResourceGroupDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
                if($parameters.ExcludeChangeType){$parameters.Remove('ExcludeChangeType')}
                if ($resultsError) {

                    if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
                        Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                        $invalidTemplate = $true
                    }
                    else {
                        Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsError.exception.InnerException.Message
                        throw $resultsError.exception.InnerException.Message
                    }

                }
                elseif ($results.Error) {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                    return
                }
                else {
                    Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                    Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                    Set-AzOpsWhatIfOutput -Results $results
                }

                $parameters.Name = $DeploymentName
                if ($PSCmdlet.ShouldProcess("Start ResourceGroup Deployment?")) {
                    if (-not $invalidTemplate) {
                        New-AzResourceGroupDeployment @parameters
                    }
                }
                else {
                    # Exit deployment
                    Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
                }
            }
        }
        #endregion Resource Group
        #region Subscription
        elseif ($scopeObject.subscription) {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-AzOpsDeployment.Subscription.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject

            if ((Get-AzContext).Subscription.Id -ne $scopeObject.subscription) {
                Set-AzOpsContext -ScopeObject $scopeObject
            }

            $parameters = @{
                'TemplateFile'                = $TemplateFilePath
                'Location'                    = $defaultDeploymentRegion
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            $WhatifExcludedChangeTypes = Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'
            if($WhatifExcludedChangeTypes){
                $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
            }
            $results = Get-AzSubscriptionDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
            if($parameters.ExcludeChangeType){$parameters.Remove('ExcludeChangeType')}
            if ($resultsError) {
                if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                    $invalidTemplate = $true
                }
                else {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsError.exception.InnerException.Message
                    throw $resultsError.exception.InnerException.Message
                }
            }
            elseif ($results.Error) {
                Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            else {
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -Results $results
            }

            $parameters.Name = $DeploymentName
            if ($PSCmdlet.ShouldProcess("Start Subscription Deployment?")) {
                if (-not $invalidTemplate) {
                    New-AzSubscriptionDeployment @parameters
                }
            }
            else {
                # Exit deployment
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion Subscription
        #region Management Group
        elseif ($scopeObject.managementGroup) {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-AzOpsDeployment.ManagementGroup.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject

            $parameters = @{
                'TemplateFile'                = $TemplateFilePath
                'Location'                    = $defaultDeploymentRegion
                'ManagementGroupId'           = $scopeObject.managementgroup
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            $WhatifExcludedChangeTypes = Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'
            if($WhatifExcludedChangeTypes){
                $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
            }
            $results = Get-AzManagementGroupDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
            if($parameters.ExcludeChangeType){$parameters.Remove('ExcludeChangeType')}
            if ($resultsError) {

                if ($resultsError.exception.InnerException.Message -match 'https://aka.ms/resource-manager-parameter-files' -and $true -eq $bicepTemplate) {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateParameterError' -Target $scopeObject
                    $invalidTemplate = $true
                }
                else {
                    Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -Target $scopeObject -Tag Error -StringValues $resultsError.exception.InnerException.Message
                    throw $resultsError.exception.InnerException.Message
                }
            }
            elseif ($results.Error) {
                Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            else {
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -Results $results
            }

            $parameters.Name = $DeploymentName
            if ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?")) {
                if (-not $invalidTemplate) {
                    New-AzManagementGroupDeployment @parameters
                }
            }
            else {
                # Exit deployment
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion Management Group
        #region Root
        elseif ($scopeObject.type -eq 'root' -and $scopeObject.scope -eq '/') {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-AzOpsDeployment.Root.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject

            $parameters = @{
                'TemplateFile'                = $TemplateFilePath
                'location'                    = $defaultDeploymentRegion
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            $WhatifExcludedChangeTypes = Get-PSFConfigValue -FullName 'AzOps.Core.WhatifExcludedChangeTypes'
            if($WhatifExcludedChangeTypes){
                $parameters.ExcludeChangeType = $WhatifExcludedChangeTypes
            }
            $results = Get-AzTenantDeploymentWhatIfResult @parameters -ErrorAction Continue -ErrorVariable resultsError
            if($parameters.ExcludeChangeType){$parameters.Remove('ExcludeChangeType')}
            if ($resultsError) {
                Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.WhatIfWarning' -StringValues $resultsError.Exception.Message -Target $scopeObject
            }
            elseif ($results.Error) {
                Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            else {
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfResults' -StringValues ($results | Out-String) -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -Results $results
            }

            $parameters.Name = $DeploymentName
            if ($PSCmdlet.ShouldProcess("Start Tenant Deployment?")) {
                New-AzTenantDeployment @parameters
            }
            else {
                # Exit deployment
                Write-PSFMessage -Level Verbose -String 'New-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion Root
        #region Unidentified
        else {
            Write-PSFMessage -Level Warning -String 'New-AzOpsDeployment.Scope.Unidentified' -Target $scopeObject -StringValues $scopeObject
        }
        #endregion Unidentified
        #endregion Process Scope
    }
}