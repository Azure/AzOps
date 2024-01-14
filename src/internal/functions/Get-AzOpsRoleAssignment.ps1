﻿function Get-AzOpsRoleAssignment {

    <#
        .SYNOPSIS
            Discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve role assignments for.
        .EXAMPLE
            > Get-AzOpsRoleAssignment -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom role assignments deployed at Management Group scope
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleAssignment.Processing' -LogStringValues $ScopeObject -Target $ScopeObject
        $apiVersion = (($script:AzOpsResourceProvider | Where-Object {$_.ProviderNamespace -eq 'Microsoft.Authorization'}).ResourceTypes | Where-Object {$_.ResourceTypeName -eq 'roleAssignments'}).ApiVersions | Select-Object -First 1
        $path = "$($scopeObject.Scope)/providers/Microsoft.Authorization/roleAssignments?api-version=$apiVersion&`$filter=atScope()"
        try {
            $parameters = @{
                Path = $path
                Method = 'GET'
            }
            # Gather roleAssignment with retry and backoff support from Invoke-AzOpsScriptBlock
            $roleAssignments = Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                Invoke-AzOpsRestMethod @parameters -ErrorAction Stop
            } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Get-AzOpsRoleAssignment.Processing.Failed' -LogStringValues $_
        }
        if ($roleAssignments) {
            $roleAssignmentMatch = @()
            foreach ($roleAssignment in $roleAssignments) {
                if ($roleAssignment.properties.scope -eq $ScopeObject.Scope) {
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleAssignment.Assignment' -LogStringValues $roleAssignment.id, $roleAssignment.properties.roleDefinitionId -Target $ScopeObject
                    $roleAssignmentMatch += [PSCustomObject]@{
                        id = $roleAssignment.id
                        name = $roleAssignment.name
                        properties = $roleAssignment.properties
                        type = $roleAssignment.type
                     }
                }
            }
            if ($roleAssignmentMatch) {
                return $roleAssignmentMatch
            }
        }
    }

}