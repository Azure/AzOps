<#
.SYNOPSIS
    This cmdlets discovers all custom policy definitions at the provided scope (Management Groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom policy definitions at the provided scope (Management Groups, subscriptions or resource groups), excluding inherited definitions.
.EXAMPLE
    # Discover all custom policy definitions deployed at Management Group scope
    Get-AzOpsPolicyDefinitionAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition
#>
function Get-AzOpsPolicyDefinitionAtScope {

    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition])]
    param (
        # Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        $CurrentPolicyDefinitionsInAzure = @()
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message "Processing $scope"
        # Discover policies at Resource Group, Subscription or Management Group level
        if ($scope.Type -in 'resourcegroups', 'subscriptions', 'managementgroups') {
            # Discover policy definitions at Management Group level
            if ($scope.type -eq 'managementGroups') {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message "Retrieving Policy Definition at ManagementGroup Scope $scope"
                $currentPolicyDefinitionsInAzure = Get-AzPolicyDefinition -Custom -ManagementGroupName $scope.name | Where-Object -FilterScript { $_.ResourceId -match $scope.scope }
            }
            # Discover policy definitions at Subscription level
            elseif ($scope.type -eq 'subscriptions') {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message "Retrieving Policy Definition at Subscription Scope $scope"
                $SubscriptionID = $scope.scope.split('/')[2]
                $CurrentPolicyDefinitionsInAzure = Get-AzPolicyDefinition -Custom -SubscriptionId $SubscriptionID | Where-Object -FilterScript { $_.SubscriptionId -eq $scope.name }
            }
            # Return object with discovered policy definitions at scope
            return $CurrentPolicyDefinitionsInAzure
        }
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message "Finished Processing $scope"
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicyDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}