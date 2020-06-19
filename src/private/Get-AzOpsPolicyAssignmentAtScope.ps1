<#
.SYNOPSIS
    This cmdlets discovers all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom policy assignments at the provided scope (Management Groups, subscriptions or resource groups), excluding inherited assignments.
.EXAMPLE
    # Discover all custom policy assignments deployed at Management Group scope
    Get-AzOpsPolicyAssignmentAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment
#>
function Get-AzOpsPolicyAssignmentAtScope {
    
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment])]
    param (
        # Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        # Ensure that required global variables are set.
        Test-AzOpsVariables
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Processing scope: $($scope.scope)"
        $currentPolicyAssignmentInAzure = @()
    }

    process {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        # Discover policies at Resource Group, Subscription or Management Group level
        if ($scope.type -eq "resourcegroups" -or $scope.type -eq "subscriptions" -or $scope.type -eq "managementGroups" ) {
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Retrieving Policy Assignment at Scope $scope"
            $currentPolicyAssignmentInAzure = Get-AzPolicyAssignment -Scope $scope.scope -WarningAction SilentlyContinue | Where-Object -FilterScript { $_.PolicyAssignmentId -match $scope.scope }            
            # Return object with discovered policy assignments
            return  $currentPolicyAssignmentInAzure
        }
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Finished processing scope: $($scope.scope)"
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}