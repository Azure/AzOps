function Get-AzOpsRoleDefinition {

    <#
        .SYNOPSIS
            Discover all custom Role Definition at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom Role Definition at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve role definitions for.
        .EXAMPLE
            > Get-AzOpsRoleDefinition -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom role definitions deployed at Management Group scope
    #>

    [OutputType([AzOpsRoleDefinition])]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        Write-PSFMessage -Level Important -String 'Get-AzOpsRoleDefinition.Processing' -StringValues $ScopeObject -Target $ScopeObject
        foreach ($roleDefinition in Get-AzRoleDefinition -Custom -Scope $ScopeObject.Scope -WarningAction SilentlyContinue) {
            #removing trailing '/' if it exists in assignable scopes
            if (($roledefinition.AssignableScopes[0] -replace "[/]$" -replace '') -eq $ScopeObject.Scope) {
                [AzOpsRoleDefinition]::new($roleDefinition)
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Get-AzOpsRoleDefinition.NonAuthorative' -StringValues $roledefinition, Id, $ScopeObject.Scope, $roledefinition.AssignableScopes[0] -Target $ScopeObject
            }
        }
    }

}