function New-AzOpsScope {
<#
	.SYNOPSIS
		Returns an AzOpsScope for a path or for a scope
	
	.DESCRIPTION
		Returns an AzOpsScope for a path or for a scope
	
	.PARAMETER Scope
		The scope for which to return a scope object.
	
	.PARAMETER Path
		The path from which to build a scope.
	
	.PARAMETER StatePath
		The root path to where the entire state is being built in.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"
		
		Return AzOpsScope for a root Management Group scope scope in Azure:
		
		scope                      : /providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560
		type                       : managementGroups
		name                       : 3fc1081d-6105-4e19-b60c-1ec1252cf560
		statepath                  : C:\git\cet-northstar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\.AzState\Microsoft.Management_managementGroups-3fc1081d-6105-4e19-b60c-1ec1252cf560.parame
		ters.json
		managementgroup            : 3fc1081d-6105-4e19-b60c-1ec1252cf560
		managementgroupDisplayName : 3fc1081d-6105-4e19-b60c-1ec1252cf560
		subscription               :
		subscriptionDisplayName    :
		resourcegroup              :
		resourceprovider           :
		resource                   :
	
	.EXAMPLE
		PS C:\> New-AzOpsScope -path  "C:\Users\jodahlbo\git\CET-NorthStar\azops\Tenant Root Group\Non-Production Subscriptions\Dalle MSDN MVP\365lab-dcs"
		
		Return AzOpsScope for a filepath
	
	.INPUTS
		Scope
	
	.INPUTS
		Path
	
	.OUTPUTS
		[AzOpsScope]
#>
	[OutputType([AzOpsScope])]
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(ParameterSetName = "scope")]
		[string]
		$Scope,
		
		[Parameter(ParameterSetName = "pathfile", ValueFromPipeline = $true)]
		[string]
		$Path,
		
		[string]
		$StatePath = (Get-PSFConfigValue -FullName 'AzOps.General.State')
	)
	
	begin {
		[regex]$regex_findAzStateFileExtension = '(?i)(.AzState)(|\\|\/)$'
	}
	process {
		Write-PSFMessage -Level Debug -String 'New-AzOpsScope.Starting'
		
		switch ($PSCmdlet.ParameterSetName) {
			scope
			{
				Invoke-PSFProtectedCommand -ActionString 'New-AzOpsScope.Creating.FromScope' -ActionStringValues $Scope -Target $Scope -ScriptBlock {
					[AzOpsScope]::new($Scope, $StatePath)
				} -EnableException $true -PSCmdlet $PSCmdlet
			}
			pathfile
			{
				$resolvedPath = $Path -replace $regex_findAzStateFileExtension, ''
				if (-not (Test-Path $resolvedPath)) {
					Stop-PSFFunction -String 'New-AzOpsScope.Path.NotFound' -StringValues $Path -EnableException $true -Cmdlet $PSCmdlet
				}
				$resolvedPath = Resolve-PSFPath -Path $resolvedPath -SingleItem -Provider FileSystem
				if (-not $resolvedPath.StartsWith($StatePath)) {
					Stop-PSFFunction -String 'New-AzOpsScope.Path.InvalidRoot' -StringValues $Path, $StatePath -EnableException $true -Cmdlet $PSCmdlet
				}
				Invoke-PSFProtectedCommand -ActionString 'New-AzOpsScope.Creating.FromFile' -Target $resolvedPath -ScriptBlock {
					[AzOpsScope]::new($(Get-Item -Path $resolvedPath), $StatePath)
				} -EnableException $true -PSCmdlet $PSCmdlet
			}
		}
	}
}