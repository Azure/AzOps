function Get-AzOpsPolicy {
    <#
        .SYNOPSIS
            Get policy objects from provided scope
        .PARAMETER ScopeObject
            ScopeObject
        .PARAMETER StatePath
            StatePath
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AzOpsScope]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Definitions', $scopeObject.Scope
        $policyDefinitions = Get-AzOpsPolicyDefinition -ScopeObject $ScopeObject
        $policyDefinitions | ConvertTo-AzOpsState -StatePath $StatePath

        # Process policyset definitions (initiatives))
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'PolicySet Definitions', $ScopeObject.Scope
        $policySetDefinitions = Get-AzOpsPolicySetDefinition -ScopeObject $ScopeObject
        $policySetDefinitions | ConvertTo-AzOpsState -StatePath $StatePath

        # Process policy assignments
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Assignments', $ScopeObject.Scope
        $policyAssignments = Get-AzOpsPolicyAssignment -ScopeObject $ScopeObject
        $policyAssignments | ConvertTo-AzOpsState -StatePath $StatePath

        # Process policy exemptions
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Policy Exemptions', $ScopeObject.Scope
        $policyExemptions = Get-AzOpsPolicyExemption -ScopeObject $ScopeObject
        $policyExemptions | ConvertTo-AzOpsState -StatePath $StatePath
    }
}