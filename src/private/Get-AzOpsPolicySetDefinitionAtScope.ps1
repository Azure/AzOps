<#
.SYNOPSIS
    This cmdlets discovers all custom policySetDefinitions at the provided scope (Management Groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom policySetDefinitions at the provided scope (Management Groups, subscriptions or resource groups), excluding inherited definitions.
.EXAMPLE
    # Discover all custom policySetDefinitions deployed at Management Group scope
    Get-AzOpsPolicySetDefinitionAtScope -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition
#>
function Get-AzOpsPolicySetDefinitionAtScope {

    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition])]
    param (
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        $currentPolicySetDefinitionsInAzure = @()
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message "Processing $scope"
        # Discover policysetsdefinitions at Resource Group, Subscription or Management Group level
        if ($scope.Type -in 'resourcegroups', 'subscriptions', 'managementgroups') {
            # Discover policysetdefinitions at Management Group level
            if ($scope.type -eq 'managementGroups') {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message "Retrieving PolicySet Definition at ManagementGroup Scope $scope"
                $currentPolicySetDefinitionsInAzure = Get-AzPolicySetDefinition -Custom -ManagementGroupName $scope.name | Where-Object -FilterScript { $_.ResourceId -match $scope.scope }
            }
            # Discover policysetdefinitions at Subscription level
            elseif ($scope.type -eq 'subscriptions') {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message "Retrieving PolicySet Definition at Subscription Scope $scope"
                $SubscriptionID = $scope.scope.split('/')[2]
                $currentPolicySetDefinitionsInAzure = Get-AzPolicySetDefinition -Custom -SubscriptionId $SubscriptionID | Where-Object -FilterScript { $_.SubscriptionId -eq $scope.name }
            }
            # Return object with discovered policysetdefinitions at scope
            return $currentPolicySetDefinitionsInAzure
        }
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message "Finished Processing $scope"
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsPolicySetDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}