function Get-AzOpsPolicyDefinition {

    <#
        .SYNOPSIS
            Discover all custom policy definitions at the provided scope (Management Groups or subscriptions)
        .DESCRIPTION
            Discover all custom policy definitions at the provided scope (Management Groups or subscriptions)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policy definitions for.
        .PARAMETER Subscription
            Complete Subscription list
        .EXAMPLE
            > Get-AzOpsPolicyDefinition -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy definitions deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.PowerShell.Cmdlets.Policy.Models.IPolicyDefinition])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $ScopeObject,
        [Parameter(Mandatory = $false)]
        [object]
        $Subscription
    )

    process {
        if ($ScopeObject.Type -notin 'subscriptions', 'managementGroups') {
            return
        }
        if ($ScopeObject.Type -eq 'managementGroups') {
            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyDefinition.ManagementGroup' -LogStringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            $query = "policyresources | where type == 'microsoft.authorization/policydefinitions' and properties.policyType == 'Custom' and subscriptionId == '' | order by ['id'] asc"
            Search-AzOpsAzGraph -ManagementGroupName $ScopeObject.Name -Query $query -ErrorAction Stop
        }
        if ($Subscription) {
            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyDefinition.Subscription' -LogStringValues $Subscription.count -Target $ScopeObject
            $query = "policyresources | where type == 'microsoft.authorization/policydefinitions' and properties.policyType == 'Custom' | order by ['id'] asc"
            Search-AzOpsAzGraph -Subscription $Subscription -Query $query -ErrorAction Stop
        }
    }

}