function Get-AzOpsPolicyDefinition {

    <#
        .SYNOPSIS
            Discover all custom policy definitions at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policy definitions at the provided scope (Management Groups, subscriptions or resource groups)
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
        [AzOpsScope]
        $ScopeObject
    )

    process {
        #TODO: Discuss dropping resourcegroups, as no action is taken ever
        if ($ScopeObject.Type -notin 'resourcegroups', 'subscriptions', 'managementGroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyDefinition.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
                Get-AzPolicyDefinition -Custom -ManagementGroupName $ScopeObject.Name | Where-Object ResourceId -match $ScopeObject.Scope
            }
            subscriptions {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyDefinition.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
                Get-AzPolicyDefinition -Custom -SubscriptionId $ScopeObject.Scope.Split('/')[2] | Where-Object SubscriptionId -eq $ScopeObject.Name
            }
        }
    }

}