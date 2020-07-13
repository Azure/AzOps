<#
.SYNOPSIS
    This cmdlets discovers all custom Role Definition at the provided scope (Management Groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom Role Definition at the provided scope (Management Groups, subscriptions or resource groups)
.EXAMPLE
    # Discover all custom policy definitions deployed at Management Group scope
    Get-AzOpsRoleDefinitionAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition
#>
function Get-AzOpsRoleDefinitionAtScope {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Processing $scope"
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        if ($scope.type -eq 'resource' -and $scope.resource -eq 'roleDefinitions') {
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Retrieving resource at $scope"

            $role = Get-AzRoleDefinition -Id ($scope.scope -split '/' | Select-Object -last 1)

            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Serializing AzOpsState for $scope at $($scope.statepath)"
            ConvertTo-AzOpsState -role $role

        }
        # Checking role definition at Subscription and Management Group only
        elseif ($scope.type -eq "subscriptions" -or $scope.type -eq "managementGroups" ) {

            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Retrieving Role Definition at Scope $scope"

            $currentRoleDefinitionsInAzure = Get-AzRoleDefinition -Custom -Scope $scope.scope
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Messages "Retrieved Role Definition at Scope - Total Count $($currentRoleDefinitionsInAzure.count)"

            foreach ($roledefinition in $currentRoleDefinitionsInAzure) {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Iterating through Role definitition at scope $scope for $($roledefinition.Id)"
                if ($roledefinition.AssignableScopes[0] -eq $scope.scope) {
                    Get-AzOpsRoleDefinitionAtScope -scope (New-AzOpsScope -scope "$($roledefinition.AssignableScopes[0])/providers/Microsoft.Authorization/roleDefinitions/$($roledefinition.Id)")
                }
                else {
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Role Definition exists at $scope however it is not auhtoriataive. Current authoritative scope is $($roledefinition.AssignableScopes[0])"
                }

            }
        }
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Finished Processing $scope"
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}