<#
.SYNOPSIS
    This cmdlets discovers all custom policySetDefinitions at the provided scope (management groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom policySetDefinitions at the provided scope (management groups, subscriptions or resource groups), excluding inherited definitions.
.EXAMPLE
    #Discover all custom policySetDefinitions deployed at management group scope
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
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
        $currentPolicySetDefinitionsInAzure = @()
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-Verbose " - Processing $scope"
        #Discover policysetsdefinitions at resourcegroup, subscription or management group level
        if ($scope.Type -in 'resourcegroups', 'subscriptions', 'managementgroups') {
            #Discover policysetdefinitions at management group level
            if ($scope.type -eq 'managementGroups') {
                Write-Verbose -Message " - Retrieving PolicySet Definition at ManagementGroup Scope $scope"
                $currentPolicySetDefinitionsInAzure = Get-AzPolicySetDefinition -Custom -ManagementGroupName $scope.name | Where-Object -FilterScript { $_.ResourceId -match $scope.scope }                
            }
            #Discover policysetdefinitions at subscription level
            elseif ($scope.type -eq 'subscriptions') {
                Write-Verbose -Message " - Retrieving PolicySet Definition at Subscription Scope $scope"
                $SubscriptionID = $scope.scope.split('/')[2]
                $currentPolicySetDefinitionsInAzure = Get-AzPolicySetDefinition -Custom -SubscriptionId $SubscriptionID | Where-Object -FilterScript { $_.SubscriptionId -eq $scope.name }
            }
            #Return object with discovered policysetdefinitions at scope
            return $currentPolicySetDefinitionsInAzure
        }
        Write-Verbose -Message " - Finished Processing $scope"
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}