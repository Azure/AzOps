function ConvertTo-AzOpsState {
<#
	.SYNOPSIS
		The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
	
	.DESCRIPTION
		The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
		It is normally executed and orchestrated through the Initialize-AzOpsRepository cmdlet. As most of the AzOps-cmdlets, it is dependant on the AzOpsAzManagementGroup and AzOpsSubscriptions variables.
		The state configuration file found at the location the 'AzOps.General.StateConfig'-config points at with custom json schema are used to determine what properties that should be excluded from different resource types as well as if the json documents should be ordered or not.
	
	.PARAMETER Resource
		Object with resource as input
	
	.PARAMETER ExportPath
		ExportPath is used if resource needs to be exported to other path than the AzOpsScope path
	
	.PARAMETER ReturnObject
		Used if to return object in pipeline instead of exporting file
	
	.PARAMETER ExportRawTemplate
		Used in cases you want to return the template without the custom parameters json schema
	
	.PARAMETER StatePath
		The root path to where the entire state is being built in.
	
	.EXAMPLE
		Initialize-AzOpsGlobalVariables
		$policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
		ConvertTo-AzOpsState -Resource $policy
	
		Export custom policy definition to the AzOps StatePath
	
	.EXAMPLE
		Initialize-AzOpsGlobalVariables
		$policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
		ConvertTo-AzOpsState -Resource $policy -ReturnObject
		
		Name                           Value
		----                           -----
		$schema                        http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#
		contentVersion                 1.0.0.0
		parameters                     {input}
	
		Serialize custom policy definition to the AzOps format, return object instead of export file
	
	.INPUTS
		Resource
	
	.OUTPUTS
		Resource in AzOpsState json format or object returned as [PSCustomObject] depending on parameters used
#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('MG', 'Role', 'Assignment', 'CustomObject', 'ResourceGroup')]
		$Resource,
		
		[string]
		$ExportPath,
		
		[switch]
		$ReturnObject,
		
		[switch]
		$ExportRawTemplate,
		
		[string]
		$StatePath = (Get-PSFConfigValue -FullName 'AzOps.General.State')
	)
	
	begin {
		Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Starting'
		
		#region Utility Functions
		function Resolve-ResourceConfiguration {
			[CmdletBinding()]
			param (
				$Resource,
				
				[AllowEmptyString()]
				[string]
				$ExportPath,
				
				[string]
				$StatePath,
				
				[Hashtable]
				$ResourceConfiguration
			)
			
			$result = [pscustomobject]@{
				Configuration  = $null
				ObjectFilePath = ''
				Resource	   = $Resource
				RequiresFilePath = $false
			}
			
			#region The Big Switch
			switch ($Resource) {
				# Tenant
				{ $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Tenant' -FunctionName 'ConvertTo-AzOpsState'
					$result.Configuration = $ResourceConfiguration.Values.tenant
					break
				}
				# Management Groups
				{ $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Management Group' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.id -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.managementGroup
					break
				}
				# Role Definitions
				{ $_ -is [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Role Definition' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope "$($Resource.AssignableScopes[0])/providers/Microsoft.Authorization/roleDefinitions/$($role.Id)" -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.roleDefinition
					break
				}
				# AzOpsRoleDefinition
				{ $_ -is [AzOpsRoleDefinition] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Role Definition' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.Id -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.roleDefinition
					break
				}
				# Role Assignments
				{ $_ -is [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Role Assignment' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.RoleAssignmentId -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.roleAssignment
					break
				}
				# AzOpsRoleAssignment
				{ $_ -is [AzOpsRoleAssignment] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Role Assignment' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.Id -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.roleAssignment
					break
				}
				# Resources
				{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Resource' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.resource
					break
				}
				# Resource Groups
				{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'ResourceGroup' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.resourceGroup
					break
				}
				# Subscriptions
				{ $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Subscription' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope "/subscriptions/$($Resource.id)" -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.subscription
					break
				}
				# Subscription from ManagementGroup Children
				{ ($_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupChildInfo] -and $_.Type -eq '/subscriptions') } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'Subscription' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.id -StatePath $StatePath).statepath
					$result.Configuration = $ResourceConfiguration.Values.subscription
					break
				}
				{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'PsPolicyDefinition' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
					$result.Resource = ConvertTo-CustomObject -InputObject $Resource
					$result.Configuration = $ResourceConfiguration.Values.policyDefinition
					break
				}
				# PsPolicySetDefinition
				{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'PsPolicySetDefinition' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
					$result.Resource = ConvertTo-CustomObject -InputObject $Resource
					$result.Configuration = $ResourceConfiguration.Values.policySetDefinition
					break
				}
				# PsPolicyAssignment
				{ $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment] } {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues 'PsPolicyAssignment' -FunctionName 'ConvertTo-AzOpsState'
					$result.ObjectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
					$result.Resource = ConvertTo-CustomObject -InputObject $Resource
					$result.Configuration = $ResourceConfiguration.Values.policyAssignment
					break
				}
				# Undetermined Object (Will require -ExportPath to be provided, error handling implemented in the caller)
				default {
					Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved.Generic' -FunctionName 'ConvertTo-AzOpsState'
					# Setting the value here so that exclusion logic can be applied. In future we can remove this.
					$result.Configuration = $ResourceConfiguration.Values.PSCustomObject
					$result.RequiresFilePath = $true
					break
				}
			}
			#endregion The Big Switch
			if ($ExportPath) {
				$result.ObjectFilePath = $ExportPath
			}
			# Clone the configuration hashtable, to avoid problems when piping multiple resources - the original hashtable remains immutable this way
			if ($result.Configuration) {
				$result.Configuration = $result.Configuration | ConvertTo-PSFHashtable
			}
			
			$result
		}
		#endregion Utility Functions
		
		#region Prepare Configuration Frame
		# Construct base json
		$parametersJson = [ordered]@{
			'$schema'	     = 'http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#'
			'contentVersion' = "1.0.0.0"
			'parameters'	 = [ordered]@{
				'input' = [ordered]@{
					'value' = $null
				}
			}
		}
		$excludedProperties = @{ }
		
		# Fetch config json
		try {
			$resourceConfig = Get-Content -Path (Get-PSFConfigValue -FullName 'AzOps.General.StateConfig') -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
		}
		catch {
			Stop-PSFFunction -String 'ConvertTo-AzOpsState.StateConfig.Error' -StringValues (Get-PSFConfigValue -FullName 'AzOps.General.StateConfig') -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_
		}
		# Load default properties to exclude if defined
		if ("excludedProperties" -in $resourceConfig.Keys) {
			$excludedProperties = $resourceConfig.excludedProperties.default
			Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.ExcludedProperties' -StringValues ($excludedProperties.Keys -join ',')
		}
		#endregion Prepare Configuration Frame
	}
	
	process {
		Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Processing' -StringValues $Resource
		
		try { $resourceData = Resolve-ResourceConfiguration -Resource $Resource -ExportPath $ExportPath -StatePath $StatePath -ResourceConfiguration $resourceConfig }
		catch {
			Write-PSFMessage -String 'ConvertTo-AzOpsState.ResourceError' -StringValues $Resource -Target $Resource -EnableException $true -PSCmdlet $PSCmdlet -ErrorRecord $_
			return
		}
		if ($resourceData.RequiresFilePath -and -not $resourceData.ObjectFilePath) {
			Write-PSFMessage -String 'ConvertTo-AzOpsState.NoExportPath' -StringValues $Resource -Target $Resource -EnableException $true -PSCmdlet $PSCmdlet
			return
		}
		Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.StatePath' -StringValues $resourceData.ObjectFilePath
		$object = $Resource
		
		
		# Create target file object if it doesn't exist
		if ($resourceData.ObjectFilePath -and -not (Test-Path -Path $resourceData.ObjectFilePath)) {
			Write-PSFMessage -String 'ConvertTo-AzOpsState.File.Create' -StringValues $resourceData.ObjectFilePath
			$null = New-Item -Path $resourceData.ObjectFilePath -ItemType "file" -Force
		}
		
		# Check if Resource has to be generalized
		if (Get-PSFConfigValue -FullName 'AzOps.General.GeneralizeTemplates') {
			# Preserve Original Template before manipulating anything
			# Only export original resource if generalize excluded properties exist
			if ("excludedProperties" -in $resourceData.Configuration.Keys) {
				# Set excludedproperties variable to generalize instead of default
				$excludedProperties = $resourceData.Configuration.excludedProperties.generalize
				Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Generalized.ExcludedProperties' -StringValues ($excludedProperties.Keys -join ',')
				# Export preserved file
				if ($resourceData.ObjectFilePath) {
					$parametersJson.parameters.input.value = $resourceData.Resource
					# ExportPath for the original state file
					$originalFilePath = $resourceData.ObjectFilePath -replace ".parameters.json", ".parameters.json.origin"
					Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Generalized.Exporting' -StringValues $originalFilePath
					ConvertTo-Json -InputObject $parametersJson -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($originalFilePath)) -Encoding utf8 -Force
				}
			}
		}
		
		if ($excludedProperties -is [hashtable]) {
			# Iterate through all properties to exclude from object
			$object = Convert-Object -Transform $excludedProperties -InputObject $object
		}
		
		# Export resource
		Write-PSFMessage -Level Verbose -String 'ConvertTo-AzOpsState.Exporting' -StringValues $resourceData.ObjectFilePath
		if ($resourceConfig.orderObject) {
			Write-PSFMessage -Level Verbose -String 'ConvertTo-AzOpsState.Object.ReOrder'
			$object = ConvertTo-CustomObject -InputObject $object -OrderObject
		}
		
		if ($ExportRawTemplate) {
			if ($ReturnObject) { $object }
			else { ConvertTo-Json -InputObject $object -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($resourceData.ObjectFilePath)) -Encoding UTF8 -Force }
		}
		else {
			$parametersJson.parameters.input.value = $object
			if ($ReturnObject) { $parametersJson }
			else { ConvertTo-Json -InputObject $parametersJson -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($resourceData.ObjectFilePath)) -Encoding UTF8 -Force }
		}
	}
}