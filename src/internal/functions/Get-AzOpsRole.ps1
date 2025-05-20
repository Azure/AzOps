function Get-AzOpsRole {
    <#
        .SYNOPSIS
            Get role objects from provided scope
        .PARAMETER ScopeObject
            ScopeObject
        .PARAMETER StatePath
            StatePath
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        # Process role definitions
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsResourceDefinition.Processing.Detail' -LogStringValues 'Role Definitions', $ScopeObject.Scope
        $roleDefinitions = Get-AzOpsRoleDefinition -ScopeObject $ScopeObject
        if ($roleDefinitions) {
            $roleDefinitions | ConvertTo-AzOpsState -StatePath $StatePath
        }

        # Process role assignments
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsResourceDefinition.Processing.Detail' -LogStringValues 'Role Assignments', $ScopeObject.Scope
        $roleAssignments = Get-AzOpsRoleAssignment -ScopeObject $ScopeObject
        if ($roleAssignments) {
            $roleAssignments | ConvertTo-AzOpsState -StatePath $StatePath
        }
    }
}