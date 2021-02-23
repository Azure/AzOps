function New-Deployment {
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
		TODO: Clarify use
	
	.PARAMETER StatePath
		The root folder under which to find the resource json.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> $AzOpsDeploymentList | Select-Object $uniqueProperties -Unique | Sort-Object -Property TemplateParameterFilePath | New-Deployment
	
		Deploy all unique deployments provided from $AzOpsDeploymentList
#>
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