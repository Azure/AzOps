function Get-Subscription {
<#
	.SYNOPSIS
		Returns a list of applicable subscriptions.
	
	.DESCRIPTION
		Returns a list of applicable subscriptions.
		"Applicable" generally refers to active, non-trial subscriptions.
	
	.PARAMETER ExcludedOffers
		Specific offers to exclude (e.g. specific trial offerings)
	
	.PARAMETER ExcludedStates
		Specific subscription states to ignore (e.g. expired subscriptions)
	
	.PARAMETER TenantId
		ID of the tenant to search in.
		Must be a connected tenant.
	
	.PARAMETER ApiVersion
		What version of the AZ Api to communicate with.
	
	.EXAMPLE
		PS C:\> Get-Subscription -TenantId $TenantId
	
		Returns active, non-trial subscriptions of the specified tenant.
#>
	[Alias('Get-AzOpsAllSubscription')]
	[CmdletBinding()]
	param (
		[string[]]
		$ExcludedOffers = (Get-PSFConfigValue -FullName 'AzOps.AzOps.ExcludedSubOffer'),
		
		[string[]]
		$ExcludedStates = (Get-PSFConfigValue -FullName 'AzOps.AzOps.ExcludedSubState'),
		
		[Parameter(Mandatory = $true)]
		[ValidateScript({ $_ -in (Get-AzContext).Tenant.Id })]
		[guid]
		$TenantId,
		
		[string]
		$ApiVersion = '2020-01-01'
	)
	
	process {
		Write-PSFMessage -String 'Get-AzOpsAllSubscription.Excluded.States' -StringValues ($ExcludedStates -join ',')
		Write-PSFMessage -String 'Get-AzOpsAllSubscription.Excluded.Offers' -StringValues ($ExcludedOffers -join ',')
		
		$nextLink = "/subscriptions?api-version=$ApiVersion"
		$allSubscriptionsResults = do {
			$allSubscriptionsJson = ((Invoke-AzRestMethod -Path $nextLink -Method GET).Content | ConvertFrom-Json -Depth 100)
			$allSubscriptionsJson.value | Where-Object tenantId -eq $TenantId
			$nextLink = $allSubscriptionsJson.nextLink -replace 'https://management\.azure\.com'
		}
		while ($nextLink)
		
		$includedSubscriptions = $AllSubscriptionsResults | Where-Object {
			$_.state -notin $ExcludedStates -and
			$_.subscriptionPolicies.quotaId -notin $ExcludedOffers
		}
		if (-not $includedSubscriptions) {
			Write-PSFMessage -Level Warning -String 'Get-AzOpsAllSubscription.NoSubscriptions' -Tag failed
			return
		}
		
		Write-PSFMessage -String 'Get-AzOpsAllSubscription.Subscriptions.Found' -StringValues $allSubscriptionsResults.Count
		if ($allSubscriptionsResults.Count -gt $includedSubscriptions.Count) {
			Write-PSFMessage -String 'Get-AzOpsAllSubscription.Subscriptions.Excluded' -StringValues ($allSubscriptionsResults.Count - $includedSubscriptions.Count)
		}
		
		if ($includedSubscriptions | Where-Object State -EQ PastDue) {
			Write-PSFMessage -String 'Get-AzOpsAllSubscription.Subscriptions.PastDue' -StringValues ($includedSubscriptions | Where-Object State -EQ PastDue).Count
		}
		Write-PSFMessage -String 'Get-AzOpsAllSubscription.Subscriptions.Included' -StringValues $includedSubscriptions.Count
		$includedSubscriptions
	}
}