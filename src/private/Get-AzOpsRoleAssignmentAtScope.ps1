<#
.SYNOPSIS
    This cmdlets discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom Role Assignment at the provided scope (Management Groups, subscriptions or resource groups)
.EXAMPLE
    # Discover all custom policy definitions deployed at Management Group scope
    Get-AzOpsRoleAssignmentAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment
#>
function Get-AzOpsRoleAssignmentAtScope {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Processing $scope"
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Retrieving Role Assignment at Scope $scope"

        $currentRoleAssignmentsInAzure = Get-AzRoleAssignment -Scope $scope.scope | Where-Object -FilterScript { $_.Scope -eq $scope.scope }
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Retrieved Role Assignment at Scope - Total Count $($currentRoleAssignmentsInAzure.count)"

        foreach ($roleassignment in $currentRoleAssignmentsInAzure) {
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Iterating through Role definitition at scope $scope for $($roleassignment.RoleAssignmentId)"
            ConvertTo-AzOpsState -assignment  $roleassignment
        }
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Finished Processing $scope"
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}