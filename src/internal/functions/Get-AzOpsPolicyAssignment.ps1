function Get-AzOpsPolicyAssignment {

    <#
        .SYNOPSIS
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policyset definitions for.
        .PARAMETER Subscription
            Complete Subscription list
        .PARAMETER SubscriptionsToIncludeResourceGroups
            Scoped Subscription list
        .PARAMETER ResourceGroup
            ResourceGroup switch indicating desired scope condition
        .EXAMPLE
            > Get-AzOpsPolicyAssignment -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy assignments deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IPolicyAssignment])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $ScopeObject,
        [Parameter(Mandatory = $false)]
        [object]
        $Subscription,
        [Parameter(Mandatory = $false)]
        [object]
        $SubscriptionsToIncludeResourceGroups,
        [Parameter(Mandatory = $false)]
        [bool]
        $ResourceGroup
    )

    process {
        if ($ScopeObject.Type -notin 'resourceGroups', 'subscriptions', 'managementGroups') {
            return
        }
        if ($ScopeObject.Type -eq 'managementGroups') {
            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyAssignment.ManagementGroup' -LogStringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            if ((-not $SubscriptionsToIncludeResourceGroups) -or (-not $ResourceGroups)) {
                $query = "policyresources | where type == 'microsoft.authorization/policyassignments' and resourceGroup == '' and subscriptionId == '' | order by ['id'] asc"
                Search-AzOpsAzGraph -ManagementGroupName $ScopeObject.Name -Query $query -ErrorAction Stop
            }
        }
        if ($Subscription) {
            if ($SubscriptionsToIncludeResourceGroups -and $ResourceGroup) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyAssignment.Subscription' -LogStringValues $SubscriptionsToIncludeResourceGroups.count -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policyassignments' and resourceGroup != '' | order by ['id'] asc"
                Search-AzOpsAzGraph -Subscription $SubscriptionsToIncludeResourceGroups -Query $query -ErrorAction Stop
            }
            elseif ($ResourceGroup) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyAssignment.ResourceGroup' -LogStringValues $Subscription.count -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policyassignments' and resourceGroup != '' | order by ['id'] asc"
                Search-AzOpsAzGraph -Subscription $Subscription -Query $query -ErrorAction Stop
            }
            else {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyAssignment.Subscription' -LogStringValues $Subscription.count -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policyassignments' and resourceGroup == '' | order by ['id'] asc"
                Search-AzOpsAzGraph -Subscription $Subscription -Query $query -ErrorAction Stop
            }
        }
    }

}