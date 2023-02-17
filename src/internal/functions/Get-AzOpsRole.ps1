﻿function Get-AzOpsRole {
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
        [Object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        # Process role definitions
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Role Definitions', $ScopeObject.Scope
        $roleDefinitions = Get-AzOpsRoleDefinition -ScopeObject $ScopeObject
        if ($roleDefinitions) {
            $roleDefinitions | ConvertTo-AzOpsState -StatePath $StatePath
        }

        # Process role assignments
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'Role Assignments', $ScopeObject.Scope
        $roleAssignments = Get-AzOpsRoleAssignment -ScopeObject $ScopeObject
        if ($roleAssignments) {
            $roleAssignments | ConvertTo-AzOpsState -StatePath $StatePath
        }
    }
}