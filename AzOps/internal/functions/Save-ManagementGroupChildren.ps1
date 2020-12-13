function Save-ManagementGroupChildren {
	<#
	.SYNOPSIS
	    Recursively build/change Management Group hierarchy in file system from provided scope.
		
	.DESCRIPTION
	    Recursively build/change Management Group hierarchy in file system from provided scope.
		
	.PARAMETER Scope
		Scope to discover - assumes [AzOpsScope] object
	
	.PARAMETER StatePath
		The root path to where the entire state is being built in.
		
	.EXAMPLE
	    PS C:\> Save-ManagementGroupChildren -Scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
		
		Discover Management Group hierarchy from scope
		
	.INPUTS
	    AzOpsScope
		
	.OUTPUTS
	    Management Group hierarchy in file system
	#>
	[Alias('Save-AzOpsManagementGroupChildren')]
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType()]
	param (
		[Parameter(Mandatory = $true)]
		$Scope,
		
		[string]
		$StatePath = (Get-PSFConfigValue -FullName 'AzOps.General.State')
	)
	
	process {
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Starting'
		Invoke-PSFProtectedCommand -ActionString 'Save-ManagementGroupChildren.Creating.Scope' -Target $Scope -ScriptBlock {
			$scopeObject = New-AzOpsScope -Scope $Scope -StatePath $StatePath -ErrorAction SilentlyContinue -Confirm:$false
		} -EnableException $true -PSCmdlet $PSCmdlet
		if (-not $scopeObject) { return } # In case -WhatIf is used
		
		Write-PSFMessage -String 'Save-ManagementGroupChildren.Processing' -StringValues $scopeObject.Scope
		
		# Construct all file paths for scope
		$scopeStatepath = $scopeObject.StatePath
		$statepathFileName = [IO.Path]::GetFileName($scopeStatepath)
		$statepathDirectory = [IO.Path]::GetDirectoryName($scopeStatepath)
		$statepathScopeDirectory = [IO.Directory]::GetParent($statepathDirectory).ToString()
		$statepathScopeDirectoryParent = [IO.Directory]::GetParent($statepathScopeDirectory).ToString()
		
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Data.StatePath' -StringValues $scopeStatepath
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Data.FileName' -StringValues $statepathFileName
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Data.Directory' -StringValues $statepathDirectory
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Data.ScopeDirectory' -StringValues $statepathScopeDirectory
		Write-PSFMessage -Level Debug -String 'Save-ManagementGroupChildren.Data.ScopeDirectoryParent' -StringValues $statepathScopeDirectoryParent
		
		if (-not (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName)) {
			# If StatePathFilename do not exists inside AzOpsState, create one
			Write-PSFMessage -String 'Save-ManagementGroupChildren.New.File' -StringValues $statepathFileName
		}
		elseif ($statepathScopeDirectoryParent -ne (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName).Directory.Parent.Parent.FullName) {
			# File Exists but parent is not the same, looking for Parent (.AzState) of a Parent to determine
			$exisitingScopePath = (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName).Directory.Parent.FullName
			Write-PSFMessage -String 'Save-ManagementGroupChildren.Moving.Source' -StringValues $exisitingScopePath
			Move-Item -Path $exisitingScopePath -Destination $statepathScopeDirectoryParent
			Write-PSFMessage -String 'Save-ManagementGroupChildren.Moving.Destination' -StringValues $statepathScopeDirectoryParent
		}
		
		switch ($scopeObject.Type) {
			managementGroups
			{
				
			}
			subscriptions
			{
				
			}
		}
		
		# Continue if scope exists (added since management group api returns disabled/inaccesible subscriptions)
		if ($scopeObject) {
			
			
			
			# Ensure StatePathFile is always written with latest Config.Existence of file does not mean all information is up to date.
			if ($scopeObject.type -eq 'managementGroups') {
				ConvertTo-AzOpsState -Resource ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scopeObject.managementgroup }) -ExportPath $scopeObject.statepath
				# Iterate through all child Management Groups recursively
				$ChildOfManagementGroups = ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scopeObject.managementgroup }).Children
				if ($ChildOfManagementGroups) {
					$ChildOfManagementGroups | Foreach-Object {
						$child = $_
						Save-ManagementGroupChildren -scopeObject $child.id
					}
				}
			}
			elseif ($scopeObject.type -eq 'subscriptions') {
				# Export subscriptions to AzOpsState
				ConvertTo-AzOpsState -Resource (($global:AzOpsAzManagementGroup).children | Where-Object { $_ -ne $null -and $_.Name -eq $scopeObject.name }) -ExportPath $scopeObject.statepath
			}
		}
		else {
			Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Scope [$($PSBoundParameters['scopeObject'])] not found in Azure or it is excluded"
		}
	}
}