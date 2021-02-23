function Register-ResourceProvider {
<#
	.SYNOPSIS
		Registers an azure resource provider.
	
	.DESCRIPTION
		Registers an azure resource provider.
		Assumes an ARM definition of a resource provider as input.
	
	.PARAMETER FileName
		The path to the file containing an ARM template defining a resource provider.
	
	.PARAMETER ScopeObject
		The current AzOps scope.
	
	.EXAMPLE
		PS C:\> Register-ResourceProvider -FileName $fileName -ScopeObject $scopeObject
	
		Registers an azure resource provider.
#>
	[CmdletBinding()]
	param (
		[string]
		$FileName,
		
		[AzOpsScope]
		$ScopeObject
	)
	
	process {
		Write-PSFMessage -String 'Register-ResourceProvider.Processing' -StringValues $ScopeObject, $FileName -Target $ScopeObject
		$currentContext = Get-AzContext
		if ($ScopeObject.Subscription -and $currentContext.Subscription.Id -ne $ScopeObject.Subscription) {
			Write-PSFMessage -String 'Register-ResourceProvider.Context.Switching' -StringValues $currentContext.Subscription.Name, $CurrentAzContext.Subscription.Id, $ScopeObject.Subscription, $ScopeObject.Name -Target $ScopeObject
			try {
				$null = Set-AzContext -SubscriptionId $ScopeObject.Subscription -ErrorAction Stop
			}
			catch {
				Stop-PSFFunction -String 'Register-ResourceProvider.Context.Failed' -StringValues $ScopeObject.SubscriptionDisplayName -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet -Target $ScopeObject
				throw "Couldn't switch context $_"
			}
		}
		
		$resourceproviders = Get-Content  $FileName | ConvertFrom-Json
		foreach ($resourceprovider  in $resourceproviders | Where-Object RegistrationState -eq 'Registered') {
			if (-not $resourceprovider.ProviderNamespace) { continue }
			
			Write-PSFMessage -String 'Register-ResourceProvider.Provider.Register' -StringValues $resourceprovider.ProviderNamespace
			Write-AzOpsLog -Level Verbose -Topic "Register-AzOpsResourceProvider" -Message "Registering Provider $($resourceprovider.ProviderNamespace)"
			Register-AzResourceProvider -Confirm:$false -Pre -ProviderNamespace $resourceprovider.ProviderNamespace
		}
	}
}