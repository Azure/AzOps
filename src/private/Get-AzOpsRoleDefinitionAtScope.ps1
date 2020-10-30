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
class AzOpsRoleDefinition {
    [string] $ResourceType
    [string] $Name
    [string] $Id
    [hashtable] $properties

    AzOpsRoleDefinition($properties) {
        $this.Id = $properties.AssignableScopes[0] + '/providers/Microsoft.Authorization/roleDefinitions/' + $properties.Id
        $this.Name = $properties.Id
        $this.properties = [ordered]@{
            assignableScopes = @($properties.AssignableScopes)
            description      = $properties.Description
            permissions      = @(
                [ordered]@{
                    actions        = @($properties.Actions)
                    dataActions    = @($properties.DataActions)
                    notActions     = @($properties.NotActions)
                    notdataActions = @($properties.NotDataActions)
                }
            )
            roleName         = $properties.Name
        }
        $this.ResourceType = "Microsoft.Authorization/roleDefinitions"
    }
}
function New-AzOpsRoleDefinition {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [OutputType([AzOpsRoleDefinition])]
        [Parameter(Position = 0, ParameterSetName = "PSRoleDefinition", ValueFromPipeline = $true)]
        [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition] $properties
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleDefinition" -Message ("Initiating function " + $MyInvocation.MyCommand + " Begin")
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleDefinition" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        return [AzOpsRoleDefinition]::new($properties)
    }
    end {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleDefinition" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}

function Get-AzOpsRoleDefinitionAtScope {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Processing $scope"
        $currentRoleDefinitionsInAzureToReturn = @()

        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Retrieving Role Definition at Scope $scope"
        [array] $currentRoleDefinitionsInAzure = Get-AzRoleDefinition -Custom -Scope $scope -WarningAction SilentlyContinue
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Retrieved Role Definition at Scope - Total Count $(($currentRoleDefinitionsInAzure | measure-object).Count)"
        foreach ($roledefinition in $currentRoleDefinitionsInAzure) {
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Iterating through Role definition at scope $scope for $($roledefinition.Id)"
            if ($roledefinition.AssignableScopes[0] -eq $scope) {
                $currentRoleDefinitionsInAzureToReturn += New-AzOpsRoleDefinition -properties $roleDefinition
            }
            else {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Role Definition exists at $scope however it is not authoritative. Current authoritative scope is $($roledefinition.AssignableScopes[0])"
            }
        }
        return $currentRoleDefinitionsInAzureToReturn
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Finished Processing $scope"
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}