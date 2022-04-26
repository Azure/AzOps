﻿function Get-AzOpsPolicySetDefinition {

    <#
        .SYNOPSIS
            Discover all custom policyset definitions at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policyset definitions at the provided scope (Management Groups, subscriptions or resource groups)
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
        #TODO: Discuss dropping resourcegroups, as no action is taken ever
        if ($ScopeObject.Type -notin 'resourcegroups', 'subscriptions', 'managementGroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicySetDefinition.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
                Get-AzPolicySetDefinition -Custom -ManagementGroupName $ScopeObject.Name | Where-Object ResourceId -match $ScopeObject.Scope
            }
            subscriptions {
                Write-PSFMessage -Level Important -String 'Get-AzOpsPolicySetDefinition.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
                Get-AzPolicySetDefinition -Custom -SubscriptionId $ScopeObject.Scope.Split('/')[2] | Where-Object SubscriptionId -eq $ScopeObject.Name
            }
        }
    }

}