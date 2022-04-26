﻿function Get-AzOpsPolicyAssignment {

    <#
        .SYNOPSIS
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policyset definitions for.
        .EXAMPLE
            > Get-AzOpsPolicyAssignment -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy assignments deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        #TODO: Discuss dropping resourcegroups, as no action is taken ever
        if ($ScopeObject.Type -notin 'resourcegroups', 'subscriptions', 'managementGroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyAssignment.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            }
            subscriptions {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyAssignment.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
            }
            resourcegroups {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicyAssignment.ResourceGroup' -StringValues $ScopeObject.ResourceGroup -Target $ScopeObject
            }
        }
        Get-AzPolicyAssignment -Scope $ScopeObject.Scope -WarningAction SilentlyContinue | Where-Object PolicyAssignmentId -match $ScopeObject.scope
    }

}