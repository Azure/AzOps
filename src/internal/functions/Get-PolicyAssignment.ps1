function Get-PolicyAssignment {

    <#
        .SYNOPSIS
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policyset definitions for.
        .EXAMPLE
            > Get-PolicyAssignment -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy assignments deployed at Management Group scope
    #>

    [Alias('Get-AzOpsPolicyAssignmentAtScope')]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AzOpsScope]
        $ScopeObject
    )

    process {
        #TODO: Discuss dropping resourcegroups, as no action is taken ever
        if ($ScopeObject.Type -notin 'resourcegroups', 'subscriptions', 'managementgroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-PSFMessage -String 'Get-PolicyAssignment.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            }
            subscriptions {
                Write-PSFMessage -String 'Get-PolicyAssignment.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
            }
            resourcegroups {
                Write-PSFMessage -String 'Get-PolicyAssignment.ResourceGroup' -StringValues $ScopeObject.ResourceGroup -Target $ScopeObject
            }
        }
        Get-AzPolicyAssignment -Scope $ScopeObject.Scope -WarningAction SilentlyContinue | Where-Object PolicyAssignmentId -match $ScopeObject.scope
    }

}