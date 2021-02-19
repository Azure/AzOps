function Get-RoleAssignment {
<#
    .SYNOPSIS
        Discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
    
    .DESCRIPTION
        Discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
    
    .PARAMETER ScopeObject
        The scope object representing the azure entity to retrieve role assignments for.
    
    .EXAMPLE
        PS C:\> Get-RoleAssignment -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
    
        Discover all custom role assignments deployed at Management Group scope
#>
    [OutputType([AzOpsRoleAssignment])]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AzOpsScope]
        $ScopeObject
    )
    
    process {
        Write-PSFMessage -String 'Get-RoleAssignment.Processing' -StringValues $ScopeObject -Target $ScopeObject
        foreach ($roleAssignment in Get-AzRoleAssignment -Scope $ScopeObject.Scope | Where-Object Scope -eq $ScopeObject.Scope) {
            Write-PSFMessage -String 'Get-RoleAssignment.Assignment' -StringValues $roleAssignment.DisplayName, $roleAssignment.RoleDefinitionName -Target $ScopeObject
            [AzOpsRoleAssignment]::new($roleAssignment)
        }
    }
}