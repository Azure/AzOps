function Get-AzOpsSubscription {

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
            > Get-AzOpsSubscription -TenantId $TenantId
            Returns active, non-trial subscriptions of the specified tenant.
    #>

    [CmdletBinding()]
    param (
        [string[]]
        $ExcludedOffers = (Get-PSFConfigValue -FullName 'AzOps.Core.ExcludedSubOffer'),

        [string[]]
        $ExcludedStates = (Get-PSFConfigValue -FullName 'AzOps.Core.ExcludedSubState'),

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -in (Get-AzContext).Tenant.Id })]
        [guid]
        $TenantId,

        [string]
        $ApiVersion = '2022-12-01'
    )

    process {
        Write-PSFMessage -Level Important -String 'Get-AzOpsSubscription.Excluded.States' -StringValues ($ExcludedStates -join ',')
        Write-PSFMessage -Level Important -String 'Get-AzOpsSubscription.Excluded.Offers' -StringValues ($ExcludedOffers -join ',')

        $nextLink = "/subscriptions?api-version=$ApiVersion"
        $allSubscriptionsResults = do {
            $allSubscriptionsJson = ((Invoke-AzRestMethod -Path $nextLink -Method GET).Content | ConvertFrom-Json -Depth 100)
            $allSubscriptionsJson.value | Where-Object tenantId -eq $TenantId
            $nextLink = $allSubscriptionsJson.nextLink -replace 'https://management\.azure\.com'
        }
        while ($nextLink)

        $includedSubscriptions = $allSubscriptionsResults | Where-Object {
            $_.state -notin $ExcludedStates -and
            $_.subscriptionPolicies.quotaId -notin $ExcludedOffers
        }
        if (-not $includedSubscriptions) {
            Write-PSFMessage -Level Warning -String 'Get-AzOpsSubscription.NoSubscriptions' -Tag failed
            return
        }

        Write-PSFMessage -Level Important -String 'Get-AzOpsSubscription.Subscriptions.Found' -StringValues $allSubscriptionsResults.Count
        if ($allSubscriptionsResults.Count -gt $includedSubscriptions.Count) {
            Write-PSFMessage -Level Important -String 'Get-AzOpsSubscription.Subscriptions.Excluded' -StringValues ($allSubscriptionsResults.Count - $includedSubscriptions.Count)
        }

        if ($includedSubscriptions | Where-Object State -EQ PastDue) {
            Write-PSFMessage -Level Warning -String 'Get-AzOpsSubscription.Subscriptions.PastDue' -StringValues ($includedSubscriptions | Where-Object State -EQ PastDue).Count
        }
        Write-PSFMessage -Level Important -String 'Get-AzOpsSubscription.Subscriptions.Included' -StringValues $includedSubscriptions.Count
        $includedSubscriptions
    }

}