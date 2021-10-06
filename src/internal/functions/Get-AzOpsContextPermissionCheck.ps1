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
        $token = (Get-AzAccessToken).Token
        $requestHeader = @{
            "Authorization" = "Bearer " + $token
            "Content-Type"  = "application/json"
        }
        $uri = "https://management.azure.com$scope/providers/Microsoft.Authorization/roleAssignments?api-version=2015-07-01"
        $roleAssignmentList = (Invoke-RestMethod -Method GET -Headers $requestheader -Uri $uri)
        foreach ($role in $roleAssignmentList.value.properties) {
            if ($scope.contains("/subscriptions")) {
                if (-not ($role.scope -eq $scope -or $role.scope -eq '/')) {
                    Continue
                }
            }
            if ($role.principalId -eq $contextObjectId) {
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
        }
        return $roleAssignmentPermissionCheck
    }
}