function Get-AzOpsPolicy {

    <#
        .SYNOPSIS
            Get policy objects from provided scope
        .PARAMETER ScopeObject
            ScopeObject
        .PARAMETER StatePath
            StatePath
        .PARAMETER Subscription
            Complete Subscription list
        .PARAMETER SubscriptionsToIncludeResourceGroups
            Scoped Subscription list
        .PARAMETER ResourceGroup
            ResourceGroup switch indicating desired scope condition
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath,
        [Parameter(Mandatory = $false)]
        [object]
        $Subscription,
        [Parameter(Mandatory = $false)]
        [object]
        $SubscriptionsToIncludeResourceGroups,
        [Parameter(Mandatory = $false)]
        [switch]
        $ResourceGroup
    )

    process {
        if (-not $ResourceGroup) {
            # Process policy definitions
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Definitions', $scopeObject.Scope
            $policyDefinitions = Get-AzOpsPolicyDefinition -ScopeObject $ScopeObject -Subscription $Subscription
            $policyDefinitionsClean = @()
            foreach ($policyDefinition in $policyDefinitions) {
                $policyDefinitionClean = $policyDefinition | ConvertTo-Json -Depth 100
                $policyDefinitionsClean += $policyDefinitionClean -replace 'T00:00:00Z' | ConvertFrom-Json -Depth 100
            }
            $policyDefinitionsClean | ConvertTo-AzOpsState -StatePath $StatePath

            # Process policy set definitions (initiatives)
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Set Definitions', $ScopeObject.Scope
            $policySetDefinitions = Get-AzOpsPolicySetDefinition -ScopeObject $ScopeObject -Subscription $Subscription
            $policySetDefinitions | ConvertTo-AzOpsState -StatePath $StatePath
        }
        # Process policy assignments
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Assignments', $ScopeObject.Scope
        $policyAssignments = Get-AzOpsPolicyAssignment -ScopeObject $ScopeObject -Subscription $Subscription -SubscriptionsToIncludeResourceGroups $SubscriptionsToIncludeResourceGroups -ResourceGroup $ResourceGroup
        $policyAssignments | ConvertTo-AzOpsState -StatePath $StatePath
    }

}