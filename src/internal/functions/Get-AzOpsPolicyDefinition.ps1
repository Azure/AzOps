function Get-AzOpsPolicyDefinition {

    <#
        .SYNOPSIS
            Discover all custom policy definitions at the provided scope (Management Groups, subscriptions)
        .DESCRIPTION
            Discover all custom policy definitions at the provided scope (Management Groups, subscriptions)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policy definitions for.
        .EXAMPLE
            > Get-AzOpsPolicyDefinition -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy definitions deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        if ($ScopeObject.Type -notin 'subscriptions', 'managementGroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyDefinition.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policydefinitions' and subscriptionId == '' and properties.policyType == 'Custom' | where id startswith '$($ScopeObject.Scope)' | order by ['id'] asc"
                Search-AzOpsAzGraph -ManagementGroup $ScopeObject.Name -Query $query -ErrorAction Stop
            }
            subscriptions {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyDefinition.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policydefinitions' and subscriptionId == '$($ScopeObject.Name)' and properties.policyType == 'Custom' | where id startswith '$($ScopeObject.Scope)' | order by ['id'] asc"
                Search-AzOpsAzGraph -SubscriptionId $ScopeObject.Name -Query $query -ErrorAction Stop
            }
        }
    }

}