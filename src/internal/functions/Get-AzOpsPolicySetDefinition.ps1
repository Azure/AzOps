function Get-AzOpsPolicySetDefinition {

    <#
        .SYNOPSIS
            Discover all custom policyset definitions at the provided scope (Management Groups or subscriptions)
        .DESCRIPTION
            Discover all custom policyset definitions at the provided scope (Management Groups or subscriptions)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policyset definitions for.
        .PARAMETER Subscription
            Complete Subscription list
        .EXAMPLE
            > Get-AzOpsPolicySetDefinition -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policyset definitions deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition])]
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
            Write-PSFMessage -Level Debug -String 'Get-AzOpsPolicySetDefinition.ManagementGroup' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            $query = "policyresources | where type == 'microsoft.authorization/policysetdefinitions' and properties.policyType == 'Custom' and subscriptionId == '' | order by ['id'] asc"
            Search-AzOpsAzGraph -ManagementGroupName $ScopeObject.Name -Query $query -ErrorAction Stop
        }
        if ($Subscription) {
            Write-PSFMessage -Level Debug -String 'Get-AzOpsPolicySetDefinition.Subscription' -StringValues $Subscription.count -Target $ScopeObject
            $query = "policyresources | where type == 'microsoft.authorization/policysetdefinitions' and properties.policyType == 'Custom' | order by ['id'] asc"
            Search-AzOpsAzGraph -Subscription $Subscription -Query $query -ErrorAction Stop
        }
    }

}