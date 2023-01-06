function Get-AzOpsPolicySetDefinition {

    <#
        .SYNOPSIS
            Discover all custom policyset definitions at the provided scope (Management Groups or subscriptions)
        .DESCRIPTION
            Discover all custom policyset definitions at the provided scope (Management Groups or subscriptions)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policyset definitions for.
        .EXAMPLE
            > Get-AzOpsPolicySetDefinition -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policyset definitions deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition])]
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
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicySetDefinition.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policysetdefinitions' and subscriptionId == '' and properties.policyType == 'Custom' | where id startswith '$($ScopeObject.Scope)' | order by ['id'] asc"
                Search-AzOpsAzGraph -ManagementGroup $ScopeObject.Name -Query $query -ErrorAction Stop
            }
            subscriptions {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicySetDefinition.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
                $query = "policyresources | where type == 'microsoft.authorization/policysetdefinitions' and subscriptionId == '$($ScopeObject.Name)' and properties.policyType == 'Custom' | where id startswith '$($ScopeObject.Scope)' | order by ['id'] asc"
                Search-AzOpsAzGraph -SubscriptionId $ScopeObject.Name -Query $query -ErrorAction Stop
            }
        }
    }

}