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

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        Write-PSFMessage -Level Debug -String 'Get-AzOpsRoleDefinition.Processing' -StringValues $ScopeObject -Target $ScopeObject
        $apiVersion = (($script:AzOpsResourceProvider | Where-Object {$_.ProviderNamespace -eq 'Microsoft.Authorization'}).ResourceTypes | Where-Object {$_.ResourceTypeName -eq 'roleDefinitions'}).ApiVersions | Select-Object -First 1
        $path = "$($scopeObject.Scope)/providers/Microsoft.Authorization/roleDefinitions?api-version=$apiVersion&`$filter=type+eq+'CustomRole'"
        $roleDefinitions = Invoke-AzOpsRestMethod -Path $path -Method GET
        if ($roleDefinitions) {
            $roleDefinitionsMatch = @()
            foreach ($roleDefinition in $roleDefinitions) {
                if ($roleDefinition.properties.assignableScopes -eq $ScopeObject.Scope) {
                    Write-PSFMessage -Level Debug -String 'Get-AzOpsRoleDefinition.Definition' -StringValues $roleDefinition.id -Target $ScopeObject
                    $roleDefinitionsMatch += [PSCustomObject]@{
                        # Removing the Trailing slash to ensure that '/' is not appended twice when adding '/providers/xxx'.
                        # Example: '/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/' is a valid assignment scope.
                        id = '/' + $roleDefinition.properties.assignableScopes[0].Trim('/') + '/providers/Microsoft.Authorization/roleDefinitions/' + $roleDefinition.id
                        name = $roleDefinition.Name
                        properties = $roleDefinition.properties
                        type = $roleDefinition.type
                     }
                }
            }
            if ($roleDefinitionsMatch) {
                return $roleDefinitionsMatch
            }
        }
    }

}