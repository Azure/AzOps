function New-Deployment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $DeploymentName = "azops-template-deployment",
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateFilePath,
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]
        $TemplateParameterFilePath,
        
        [string]
        $Mode = "Incremental",
        
        [string]
        $StatePath
    )
    
    process {
        Write-PSFMessage -String 'New-Deployment.Processing' -StringValues $DeploymentName, $TemplateFilePath, $TemplateParameterFilePath, $Mode -Target $TemplateFilePath
        #region Resolve Scope
        try {
            if ($TemplateParameterFilePath) {
                $scopeObject = New-AzOpsScope -Path $TemplateParameterFilePath -StatePath $StatePath -ErrorAction Stop
            }
            else {
                $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop
            }
        }
        catch {
            Write-PSFMessage -Level Warning -String 'New-Deployment.Scope.Failed' -Target $TemplateFilePath -StringValues $TemplateFilePath, $TemplateParameterFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-PSFMessage -Level Warning -String 'New-Deployment.Scope.Empty' -Target $TemplateFilePath -StringValues $TemplateFilePath, $TemplateParameterFilePath
            return
        }
        #endregion Resolve Scope
        
        #region Process Scope
        #region Resource Group
        if ($scopeObject.resourcegroup) {
            Write-PSFMessage -String 'New-Deployment.ResourceGroup.Processing' -StringValues $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            
            $parameters = @{
                'TemplateFile'			      = $TemplateFilePath
                'SkipTemplateParameterPrompt' = $true
                'ResourceGroupName'		      = $scopeObject.resourcegroup
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            # Validate Template
            $results = Test-AzResourceGroupDeployment @parameters
            if ($results) {
                Write-PSFMessage -Level Warning -String 'New-Deployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            
            $parameters.Name = $DeploymentName
            if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                # Whatif Placeholder
                New-AzResourceGroupDeployment @parameters -WhatIf -WhatIfResultFormat FullResourcePayloads
            }
            else {
                New-AzResourceGroupDeployment @parameters
            }
        }
        #endregion Resource Group
        #region Subscription
        elseif ($scopeObject.subscription) {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.General.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-Deployment.Subscription.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            Set-AzOpsContext -ScopeObject $scopeObject
            
            $parameters = @{
                'TemplateFile'			      = $TemplateFilePath
                'Location'				      = $defaultDeploymentRegion
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            # Validate Template
            $results = Test-AzSubscriptionDeployment @parameters
            if ($results) {
                Write-PSFMessage -Level Warning -String 'New-Deployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            
            $parameters.Name = $DeploymentName
            if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                # Whatif Placeholder
                New-AzSubscriptionDeployment @parameters -WhatIf -WhatIfResultFormat FullResourcePayloads
            }
            else {
                New-AzSubscriptionDeployment @parameters
            }
        }
        #endregion Subscription
        #region Management Group
        elseif ($scopeObject.managementGroup) {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.General.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-Deployment.ManagementGroup.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            
            $parameters = @{
                'TemplateFile'	    = $TemplateFilePath
                'location'		    = $defaultDeploymentRegion
                'ManagementGroupId' = $scopeObject.managementgroup
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            # Validate Template
            $results = Test-AzManagementGroupDeployment @parameters
            if ($results) {
                Write-PSFMessage -Level Warning -String 'New-Deployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            
            $parameters.Name = $DeploymentName
            if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                # Whatif Placeholder
                New-AzManagementGroupDeployment @parameters -WhatIf
            }
            else {
                New-AzManagementGroupDeployment @parameters
            }
        }
        #endregion Management Group
        #region Root
        elseif ($scopeObject.type -eq 'root' -and $scopeObject.scope -eq '/') {
            $defaultDeploymentRegion = Get-PSFConfigValue -FullName 'AzOps.General.DefaultDeploymentRegion'
            Write-PSFMessage -String 'New-Deployment.Root.Processing' -StringValues $defaultDeploymentRegion, $scopeObject -Target $scopeObject
            
            $parameters = @{
                'TemplateFile'			      = $TemplateFilePath
                'location'				      = $defaultDeploymentRegion
                'SkipTemplateParameterPrompt' = $true
            }
            if ($TemplateParameterFilePath) {
                $parameters.TemplateParameterFile = $TemplateParameterFilePath
            }
            # Validate Template
            $results = Test-AzTenantDeployment @parameters
            if ($results) {
                Write-PSFMessage -Level Warning -String 'New-Deployment.TemplateError' -StringValues $TemplateFilePath -Target $scopeObject
                return
            }
            
            $parameters.Name = $DeploymentName
            if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                # Whatif Placeholder
                New-AzTenantDeployment @parameters -WhatIf
            }
            else {
                New-AzTenantDeployment @parameters
            }
        }
        #endregion Root
        #region Unidentified
        else {
            Write-PSFMessage -Level Warning -String 'New-Deployment.Scope.Unidentified' -Target $scopeObject -StringValues $scopeObject
        }
        #endregion Unidentified
        #endregion Process Scope
    }
}