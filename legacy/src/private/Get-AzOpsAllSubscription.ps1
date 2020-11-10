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
        [string[]]$ExcludedStates = @('Disabled', 'Deleted', 'Warned', 'Expired'),
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
        # Get all subscriptions in current tenant and and exclude states/offers

        $AllSubscriptionsResults = @()
        $nextLink = $null
        $AllSubscriptionsJson = ((Invoke-AzRestMethod -Path /subscriptions?api-version=$ApiVersion -Method GET).Content | ConvertFrom-Json -Depth 100)
        $AllSubscriptionsResults += $AllSubscriptionsJson.value | Where-Object { $_.tenantId -eq $TenantId }

        while (Get-Member -InputObject $AllSubscriptionsJson -name "nextLink" -MemberType Properties) {
            $AllSubscriptionsJson2 = ((Invoke-AzRestMethod -Path $AllSubscriptionsJson.nextLink.Replace('https://management.azure.com', '')  -Method GET).Content | ConvertFrom-Json -Depth 100)
            $AllSubscriptionsResults += $AllSubscriptionsJson2.value | Where-Object { $_.tenantId -eq $TenantId }
            $AllSubscriptionsJson = $AllSubscriptionsJson2
        }

        $IncludedSubscriptions = $AllSubscriptionsResults | Where-Object { $_.state -notin $ExcludedStates -and $_.subscriptionPolicies.quotaId -notin $ExcludedOffers }
        # Validate that subscriptions were found
        if ($null -eq $IncludedSubscriptions) {
            Write-AzOpsLog -Level Error -Topic "Get-AzOpsAllSubscription" -Message "Found [$(($IncludedSubscriptions | Measure-Object).Count)] subscriptions - verify appropriate permissions or that excluded offers and states are correct"
        }
        else {
            # Calculate no of excluded subscriptions
            [int]$ExcludedSubscriptions = ($AllSubscriptionsResults.count - $IncludedSubscriptions.Count)
            if ($ExcludedSubscriptions -gt 0) {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Found total [$($AllSubscriptionsResults.count)] subscriptions"
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Excluded [$ExcludedSubscriptions] subscriptions due to state or offer"
            }
            # Throw warning for subscriptions that are "PastDue"
            $PastDueSubscriptions = $IncludedSubscriptions | Where-Object { $_.State -eq "PastDue" }
            if ($PastDueSubscriptions) {
                Write-AzOpsLog -Level Warning -Topic "Get-AzOpsAllSubscription" -Message "Found [$($PastDueSubscriptions.count)] subscriptions that are in state 'PastDue' - ensure billing works correctly and resolve past due balance as per https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/resolve-past-due-balance"
            }
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsAllSubscription" -Message "Including [$($IncludedSubscriptions.count)] subscriptions"
            # Return object with subscriptions
            return $IncludedSubscriptions
        }

    }
    end {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsAllSubscription" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")

    }
}

