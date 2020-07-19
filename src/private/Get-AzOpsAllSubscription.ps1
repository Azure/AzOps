<#
.SYNOPSIS
    The cmdlet will return all subscriptions in current AzContext excluding the offers and states provided in input parameters.
.DESCRIPTION
    The cmdlet will return all subscriptions in current AzContext excluding the offers and states provided in input parameters.
.EXAMPLE
    Get-AzOpsAllSubscription
.PARAMETER ExcludedOffers
    Subscription offers to exclude
.PARAMETER ExcludedStates
    Subscription states to exclude
.PARAMETER TenantId
    TenantId to query
.PARAMETER ApiVersion
    API Version to use for the subscription API
.OUTPUTS
    System.Management.Automation.PSCustomObject
#>
function Get-AzOpsAllSubscription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$ExcludedOffers = @('AzurePass_2014-09-01', 'FreeTrial_2014-09-01', 'AAD_2015-09-01'),
        [Parameter(Mandatory = $false)]
        [string[]]$ExcludedStates = @('Disabled', 'Deleted', 'Warned', 'Expired', 'PastDue'),
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ -in (Get-AzContext).Tenant.Id } )]
        [guid]$TenantId,
        [Parameter(Mandatory = $false)]
        [string]$ApiVersion = '2020-01-01'
    )
    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsAllSubscription" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsAllSubscription" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Excluded subscription states are: $(($ExcludedStates -join ','))"
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Excluded subscription offers are: $(($ExcludedOffers -join ','))"
        # Get all subscriptions and exclude states/offers
        $AllSubscriptions = ((Invoke-AzRestMethod -Path /subscriptions?api-version=$ApiVersion -Method GET).Content | ConvertFrom-Json -Depth 100).Value | Where-Object { $_.state -notin $ExcludedStates -and $_.subscriptionPolicies.quotaId -notin $ExcludedOffers -and $_.tenantId -eq $TenantId }
        if ($null -eq $AllSubscriptions) {
            Write-AzOpsLog -Level Error -Topic "Get-AzOpsAllSubscription" -Message "Found [$($AllSubscriptions.count)] subscriptions - do you have permissions to any subscriptions?"
        }
        else {
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Found [$($AllSubscriptions.count)] subscriptions"
        }

    }
    end {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsAllSubscription" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
        return $AllSubscriptions
    }
}

