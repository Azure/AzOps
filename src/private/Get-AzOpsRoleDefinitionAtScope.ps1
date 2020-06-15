<#
.SYNOPSIS
    This cmdlets discovers all custom Role Definition at the provided scope (management groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom Role Definition at the provided scope (management groups, subscriptions or resource groups)
.EXAMPLE
    #Discover all custom policy definitions deployed at management group scope
    Get-AzOpsRoleDefinitionAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition
#>
function Get-AzOpsRoleDefinitionAtScope {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        Write-Verbose -Message " - Processing $scope"
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        if ($scope.type -eq 'resource' -and $scope.resource -eq 'roleDefinitions') {
            Write-Verbose " - Retrieving resource at $scope"

            $role = Get-AzRoleDefinition -Id ($scope.scope -split '/' | Select-Object -last 1)

            Write-Verbose -Message " - Serializing AzOpsState for $scope at $($scope.statepath)"
            ConvertTo-AzOpsState -role $role

        }
        #Checking role definition at Subscription and Management Group only
        elseif ($scope.type -eq "subscriptions" -or $scope.type -eq "managementGroups" ) {

            Write-Verbose -Message " - Retrieving Role Definition at Scope $scope"

            $currentRoleDefinitionsInAzure = Get-AzRoleDefinition -Custom -Scope $scope.scope
            Write-Verbose -Messages " - Retrieved Role Definition at Scope - Total Count $($currentRoleDefinitionsInAzure.count)"

            foreach ($roledefinition in $currentRoleDefinitionsInAzure) {
                Write-Verbose -Message " - Iterating through Role definitition at scope $scope for $($roledefinition.Id)"
                if ($roledefinition.AssignableScopes[0] -eq $scope.scope) {
                    Get-AzOpsRoleDefinitionAtScope -scope (New-AzOpsScope -scope "$($roledefinition.AssignableScopes[0])/providers/Microsoft.Authorization/roleDefinitions/$($roledefinition.Id)")
                }
                else {
                    Write-Verbose -Message " - Role Definition exists at $scope however it is not auhtoriataive. Current authoritative scope is $($roledefinition.AssignableScopes[0])"
                }

            }
        }
    }

    end {
        Write-Verbose -Message " - Finished Processing $scope"
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}