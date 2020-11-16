function Initialize-AzOpsRepository {
<#
	.SYNOPSIS
		A brief description of the Initialize-AzOpsRepository function.
	
	.DESCRIPTION
		A detailed description of the Initialize-AzOpsRepository function.
	
	.PARAMETER SkipPolicy
		Skip discovery of policies for better performance.
	
	.PARAMETER SkipRole
		Skip discovery of role.
	
	.PARAMETER SkipResourceGroup
		Skip discovery of resource groups resources for better performance
	
	.PARAMETER InvalidateCache
		Invalidate cached subscriptions and Management Groups and do a full discovery.
	
	.PARAMETER GeneralizeTemplates
		Will generalize json templates (only used when generating azopsreference).
	
	.PARAMETER ExportRawTemplate
		Export generic templates without embedding them in the parameter block.
	
	.PARAMETER Rebuild
		Delete all .AzState folders inside AzOpsState directory.
	
	.PARAMETER Force
		Delete $global:AzOpsState directory.
	
	.EXAMPLE
		PS C:\> Initialize-AzOpsRepository
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[switch]
		$SkipPolicy,
		
		[switch]
		$SkipRole,
		
		[Parameter(Mandatory = $false)]
		[switch]
		$SkipResourceGroup,
		
		[Parameter(Mandatory = $false)]
		[switch]
		$InvalidateCache = (Get-PSFConfigValue -FullName 'AzOps.AzOps.InvalidateCache'),
		
		[Parameter(Mandatory = $false)]
		[switch]
		$GeneralizeTemplates = (Get-PSFConfigValue -FullName 'AzOps.AzOps.GeneralizeTemplates'),
		
		[Parameter(Mandatory = $false)]
		[switch]
		$ExportRawTemplate = (Get-PSFConfigValue -FullName 'AzOps.AzOps.ExportRawTemplate'),
		
		[Parameter(Mandatory = $false)]
		[switch]
		$Rebuild,
		
		[Parameter(Mandatory = $false)]
		[switch]
		$Force,
		
		[switch]
		$PartialMgDiscovery = (Get-PSFConfigValue -FullName 'AzOps.AzOps.PartialMgDiscoveryRoot'),
		
		[string[]]
		$PartialMgDiscoveryRoot = (Get-PSFConfigValue -FullName 'AzOps.AzOps.PartialMgDiscoveryRoot'),
		
		[string]
		$StatePath = (Get-PSFConfigValue -FullName 'AzOps.AzOps.State')
	)
	
	begin {
		#region Initialize & Prepare
		Write-PSFMessage -String 'Initialize-AzOpsRepository.Initialization.Starting'
		if ($SkipRole) {
			try {
				Write-PSFMessage -String 'Initialize-AzOpsRepository.Validating.UserRole'
				$null = Get-AzADUser -First 1 -ErrorAction Stop
				Write-PSFMessage -String 'Initialize-AzOpsRepository.Validating.UserRole.Success'
			}
			catch {
				Write-PSFMessage -Level Warning -String 'Initialize-AzOpsRepository.Validating.UserRole.Failed'
				$SkipRole = $true
			}
		}
		
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include InvalidateCache, PartialMgDiscovery, PartialMgDiscoveryRoot
		Initialize-AzOpsEnvironment @parameters
		
		Assert-AzOpsInitialization -Cmdlet $PSCmdlet -StatePath $StatePath
		
		$tenantId = (Get-AzContext).Tenant.Id
		Write-PSFMessage -String 'Initialize-AzOpsRepository.Tenant' -StringValues $tenantId
		
		Write-PSFMessage -String 'Initialize-AzOpsRepository.Initialization.Completed'
		
		$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
		#endregion Initialize & Prepare
	}
	process {
		#region Existing Content
		if (Test-Path $StatePath) {
			$migrationRequired = (Get-ChildItem -Recurse -Force -Path $StatePath -File | Where-Object {
					$_.Name -like "Microsoft.Management_managementGroups-$tenantId.parameters.json"
				} | Select-Object -ExpandProperty FullName -First 1) -notmatch '\((.*)\)'
			if ($migrationRequired) {
				Write-PSFMessage -String 'Initialize-AzOpsRepository.Migration.Required'
			}
			
			if ($Force -or $migrationRequired) {
				Invoke-PSFProtectedCommand -ActionString 'Initialize-AzOpsRepository.Deleting.State' -ActionStringValues $StatePath -Target $StatePath -ScriptBlock {
					Remove-Item -Path $StatePath -Recurse -Force -Confirm:$false -ErrorAction Stop
				} -EnableException $true -PSCmdlet $PSCmdlet
			}
			if ($Rebuild) {
				Invoke-PSFProtectedCommand -ActionString 'Initialize-AzOpsRepository.Rebuilding.State' -ActionStringValues $StatePath -Target $StatePath -ScriptBlock {
					Get-ChildItem -Path $StatePath -Directory -Recurse -Force -Include '.AzState' -ErrorAction Stop | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction Stop
				} -EnableException $true -PSCmdlet $PSCmdlet
			}
		}
		#endregion Existing Content
		
		#region Root Scopes
		$rootScope = '/providers/Microsoft.Management/managementGroups/{0}' -f $tenantId
		if ($PartialMgDiscovery -and $PartialMgDiscoveryRoot) {
			$rootScope = $script:AzOpsPartialRoot.id | Sort-Object -Unique
		}
		
		foreach ($root in $rootScope) {
			if ($script:AzOpsAzManagementGroup.Id -notcontains $root) {
				Write-PSFMessage -Level Warning -String 'Initialize-AzOpsRepository.ManagementGroup.AccessError' -StringValues (Get-AzContext).Account.Id
				Write-Error "Cannot access root management group $root - verify that principal $((Get-AzContext).Account.Id) has access"
				continue
			}
			
			#TODO: Implement
			# Create AzOpsState Structure recursively
			Save-AzOpsManagementGroupChildren -scope $Root
			
			#TODO: Implement
			# Discover Resource at scope recursively
			Get-AzOpsResourceDefinitionAtScope -scope $Root -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -SkipResourceGroup:$SkipResourceGroup
		}
		#endregion Root Scopes
	}
	end {
		$stopWatch.Stop()
		Write-PSFMessage -String 'Initialize-AzOpsRepository.Duration' -StringValues $stopWatch.Elapsed -Data @{ Elapsed = $stopWatch.Elapsed }
	}
}