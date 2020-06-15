<#
.SYNOPSIS
    This cmdlets discovers all custom policy definitions at the provided scope (management groups, subscriptions or resource groups)
.DESCRIPTION
    This cmdlets discovers all custom policy definitions at the provided scope (management groups, subscriptions or resource groups), excluding inherited definitions.
.EXAMPLE
    #Discover all custom policy definitions deployed at management group scope
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
        #Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
        $CurrentPolicyDefinitionsInAzure = @()
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-Verbose " - Processing $scope"
        #Discover policies at resourcegroup, subscription or management group level
        if ($scope.Type -in 'resourcegroups', 'subscriptions', 'managementgroups') {
            #Discover policy definitions at management group level
            if ($scope.type -eq 'managementGroups') {
                Write-Verbose -Message " - Retrieving Policy Definition at ManagementGroup Scope $scope"
                $currentPolicyDefinitionsInAzure = Get-AzPolicyDefinition -Custom -ManagementGroupName $scope.name | Where-Object -FilterScript { $_.ResourceId -match $scope.scope }
            }
            #Discover policy definitions at subscription level
            elseif ($scope.type -eq 'subscriptions') {
                Write-Verbose -Message " - Retrieving Policy Definition at Subscription Scope $scope"
                $SubscriptionID = $scope.scope.split('/')[2]
                $CurrentPolicyDefinitionsInAzure = Get-AzPolicyDefinition -Custom -SubscriptionId $SubscriptionID | Where-Object -FilterScript { $_.SubscriptionId -eq $scope.name }
            }
            #Return object with discovered policy definitions at scope
            return $CurrentPolicyDefinitionsInAzure
        }
        Write-Verbose -Message " - Finished Processing $scope"
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}