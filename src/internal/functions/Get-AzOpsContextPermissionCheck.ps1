function Get-AzOpsContextPermissionCheck {

    <#
        .SYNOPSIS
            Validates if context has permission specified in validatePermissionList.
        .DESCRIPTION
            Validates if context has permission specified in validatePermissionList.
        .PARAMETER contextObjectId
            The ObjectId of the Context SPN
        .PARAMETER scope
            Scope of the resource
        .PARAMETER validatePermissionList
            The permission list to perform operation.
        .EXAMPLE
            > Get-AzOpsContextPermissionCheck -contextObjectId $contextObjectId -scope $scope -validatePermissionList $validatePermissionList
            Validates if context contains anyone of permission mentioned in validatePermissionList
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $contextObjectId,

        [Parameter(Mandatory = $true)]
        $scope,

        [Parameter(Mandatory = $true)]
        $validatePermissionList
    )

    process {
        $roleAssignmentPermissionCheck = $false
        $roleAssignmentList = Get-AzRoleAssignment -Scope $scope | Where-Object { $_.ObjectId -eq $contextObjectId }
        foreach ($role in $roleAssignmentList) {
            $roleassignmentScope = $role.Scope.ToLower()
            if ((-not($scope.contains("/resourcegroups"))) -and $roleassignmentScope.contains("/resourcegroups")) {
                Continue
            }
            if ($scope.contains("/resourcegroups") -and (-not ($scope.contains("/providers")))) {
                if ($roleassignmentScope.contains("/providers") -and (-not ($roleassignmentScope.contains("/microsoft.management/managementgroups")))) {
                    Continue
                }
            }
            foreach ($item in $validatePermissionList) {
                $roledefinitionId = $role.roleDefinitionId.Substring($role.roleDefinitionId.LastIndexOf('/') + 1)
                if (Get-AzRoleDefinition -Id $roledefinitionId | Where-Object { $_.Actions -contains $item -or $_.Actions -eq "*" }) {
                    $roleAssignmentPermissionCheck = $true
                    break
                }
            }
            if ($roleAssignmentPermissionCheck -eq $true) {
                break
            }
        }
        return $roleAssignmentPermissionCheck
    }
}