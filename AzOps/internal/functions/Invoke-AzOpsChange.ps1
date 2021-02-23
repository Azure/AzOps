function Invoke-AzOpsChange {
<#
	.SYNOPSIS
		Applies a change to Azure from the AzOps configuration.
	
	.DESCRIPTION
		Applies a change to Azure from the AzOps configuration.
	
	.PARAMETER ChangeSet
		Set of changes from the last execution that need to be applied.
	
	.PARAMETER StatePath
		The root path to where the entire state is being built in.
	
	.PARAMETER AzOpsMainTemplate
		Path to the main template used by AzOps
	
	.EXAMPLE
		PS C:\> Invoke-AzOpsChange -ChangeSet changeSet -StatePath $StatePath -AzOpsMainTemplate $templatePath
	
		Applies a change to Azure from the AzOps configuration.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string[]]
		$ChangeSet,
		
		[Parameter(Mandatory = $true)]
		[string]
		$StatePath,
		
		[Parameter(Mandatory = $true)]
		[string]
		$AzOpsMainTemplate
	)
	
	begin {
		#region Utility Functions
		function Resolve-ArmFileAssociation {
			[CmdletBinding()]
			param (
				[AzOpsScope]
				$ScopeObject,
				
				[string]
				$FilePath,
				
				[string]
				$AzOpsMainTemplate
			)
			
			#region Initialization Prep
			$common = @{
				Level	     = 'Host'
				Tag		     = 'pwsh'
				FunctionName = 'Invoke-AzOpsChange'
				Target	     = $ScopeObject
			}
			
			$result = [PSCustomObject] @{
				TemplateFilePath		  = $null
				TemplateParameterFilePath = $null
				DeploymentName		      = $null
				ScopeObject			      = $ScopeObject
				Scope					  = $ScopeObject.Scope
			}
			
			$fileItem = Get-Item -Path $FilePath
			if ($fileItem.Extension -ne '.json') {
				Write-PSFMessage -Level Warning -String 'Invoke-AzOpsChange.Resolve.NoJson' -StringValues $fileItem.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsChange' -Target $ScopeObject
				return
			}
			#endregion Initialization Prep
			
			#region Case: Parameters File
			if ($fileItem.Name -like '*.parameters.json') {
				$result.TemplateParameterFilePath = $fileItem.FullName
				$deploymentName = $fileItem.BaseName -replace '\.parameters$' -replace ' ', '_'
				if ($deploymentName.Length -gt 58) { $deploymentName = $deploymentName.SubString(0, 58) }
				$result.DeploymentName = "AzOps-$deploymentName"
				
				#region Directly Associated Templatefile exists
				$templatePath = $fileItem.FullName -replace '\.parameters\.json$', '.json'
				
				if (Test-Path $templatePath) {
					Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.FoundTemplate' -StringValues $FilePath, $templatePath
					$result.TemplateFilePath = $templatePath
					return $result
				}
				#endregion Directly Associated Templatefile exists
				
				#region Check in the main template file for a match
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.NotFoundTemplate' -StringValues $FilePath, $templatePath
				$mainTemplateItem = Get-Item $AzOpsMainTemplate
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.FromMainTemplate' -StringValues $mainTemplateItem.FullName
				
				# Determine Resource Type in Parameter file
				$templateParameterFileHashtable = Get-Content -Path $fileItem.FullName | ConvertFrom-Json -AsHashtable
				$effectiveResourceType = $null
				if ($templateParameterFileHashtable.Keys -contains "`$schema") {
					if ($templateParameterFileHashtable.parameters.input.value.Keys -contains "Type") {
						# ManagementGroup and Subscription
						$effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.Type
					}
					elseif ($templateParameterFileHashtable.parameters.input.value.Keys -contains "ResourceType") {
						# Resource
						$effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.ResourceType
					}
				}
				# Check if generic template is supporting the resource type for the deployment.
				if ($effectiveResourceType -and
					(Get-Content $mainTemplateItem.FullName | ConvertFrom-Json -AsHashtable).variables.apiVersionLookup.Keys -contains $effectiveResourceType) {
					Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.MainTemplate.Supported' -StringValues $effectiveResourceType, $AzOpsMainTemplate.FullName
					$result.TemplateFilePath = $mainTemplateItem.FullName
					return $result
				}
				Write-PSFMessage -Level Warning -String 'Invoke-AzOpsChange.Resolve.MainTemplate.NotSupported' -StringValues $effectiveResourceType, $AzOpsMainTemplate.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsChange' -Target $ScopeObject
				return
				#endregion Check in the main template file for a match
				# All Code paths end the command
			}
			#endregion Case: Parameters File
			
			#region Case: Template File
			$result.TemplateFilePath = $fileItem.FullName
			$parameterPath = $fileItem.FullName -replace '\.json$', '.parameters.json'
			if (Test-Path -Path $parameterPath) {
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.ParameterFound' -StringValues $FilePath, $parameterPath
				$result.TemplateParameterFilePath = $parameterPath
			}
			else {
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Resolve.ParameterNotFound' -StringValues $FilePath, $parameterPath
			}
			
			$deploymentName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
			if ($deploymentName.Length -gt 58) { $deploymentName = $deploymentName.SubString(0,58) }
			$result.DeploymentName = "AzOps-$deploymentName"
			
			$result
			#endregion Case: Template File
		}
		#endregion Utility Functions
		$common = @{
			Level = 'Host'
			Tag   = 'git'
		}
	}
	process {
		if (-not $ChangeSet) { return }
		
		#region Categorize Input
		Write-PSFMessage @common -String 'Invoke-AzOpsChange.Deployment.Required'
		$deleteSet = @()
		$addModifySet = foreach ($change in $ChangeSet) {
			$operation, $filename = ($change -split "`t")[0, -1]
			if ($operation -eq 'D') {
				$deleteSet += $filename
				continue
			}
			if ($operation -in 'A', 'M', 'R') { $filename }
		}
		if ($deleteSet) { $deleteSet = $deleteSet | Sort-Object }
		if ($addModifySet) { $addModifySet = $addModifySet | Sort-Object }
		#TODO: Clarify what happens with the deletes - not used after reporting them
		
		Write-PSFMessage @common -String 'Invoke-AzOpsChange.Change.AddModify'
		foreach ($item in $addModifySet) {
			Write-PSFMessage @common -String 'Invoke-AzOpsChange.Change.AddModify.File' -StringValues $item
		}
		Write-PSFMessage @common -String 'Invoke-AzOpsChange.Change.Delete'
		foreach ($item in $deleteSet) {
			Write-PSFMessage @common -String 'Invoke-AzOpsChange.Change.Delete.File' -StringValues $item
		}
		#endregion Categorize Input
		
		#region Deploy State
		$common.Tag = 'pwsh'
		# Nested Pipeline allows economizing on New-StateDeployment having to run its "begin" block once only
		$newStateDeploymentCmd = { New-StateDeployment -StatePath $StatePath }.GetSteppablePipeline()
		$newStateDeploymentCmd.Begin($true)
		foreach ($addition in $addModifySet) {
			if ($addition -notmatch '/*.subscription.json$') { continue }
			Write-PSFMessage @common -String 'Invoke-AzOpsChange.Deploy.Subscription' -StringValues $addition -Target $addition
			$newStateDeploymentCmd.Process($addition)
		}
		foreach ($addition in $addModifySet) {
			if ($addition -notmatch '/*.providerfeatures.json$') { continue }
			Write-PSFMessage @common -String 'Invoke-AzOpsChange.Deploy.ProviderFeature' -StringValues $addition -Target $addition
			$newStateDeploymentCmd.Process($addition)
		}
		foreach ($addition in $addModifySet) {
			if ($addition -notmatch '/*.resourceproviders.json$') { continue }
			Write-PSFMessage @common -String 'Invoke-AzOpsChange.Deploy.ResourceProvider' -StringValues $addition -Target $addition
			$newStateDeploymentCmd.Process($addition)
		}
		$newStateDeploymentCmd.End()
		#endregion Deploy State
		
		$azOpsDeploymentList = foreach ($addition in $addModifySet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {
			try { $scopeObject = New-AzOpsScope -Path $addition -StatePath $StatePath -ErrorAction Stop }
			catch {
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Scope.Failed' -StringValues $addition, $StatePath -Target $addition -ErrorRecord $_
				continue
			}
			if (-not $scopeObject) {
				Write-PSFMessage @common -String 'Invoke-AzOpsChange.Scope.NotFound' -StringValues $addition, $StatePath -Target $addition
				continue
			}
			
			Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $addition -AzOpsMainTemplate $AzOpsMainTemplate
		}
		
		#Starting Tenant Deployment
		$uniqueProperties = 'Scope', 'DeploymentName', 'TemplateFilePath', 'TemplateParameterFilePath'
		$AzOpsDeploymentList | Select-Object $uniqueProperties -Unique | Sort-Object -Property TemplateParameterFilePath | New-Deployment
	}
}