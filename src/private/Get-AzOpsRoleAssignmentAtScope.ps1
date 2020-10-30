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

class AzOpsRoleAssignment {
    [string] $ResourceType
    [string] $Name
    [string] $Id
    [hashtable]$properties

    AzOpsRoleAssignment($properties) {
        $this.properties = [ordered]@{
            DisplayName        = $properties.DisplayName
            PrincipalId        = $properties.ObjectId
            RoleDefinitionName = $properties.RoleDefinitionName
            ObjectType         = $properties.ObjectType
            RoleDefinitionId   = '/providers/Microsoft.Authorization/RoleDefinitions/{0}' -f $properties.RoleDefinitionId
        }
        $this.Id = $properties.RoleAssignmentId
        $this.Name = ($properties.RoleAssignmentId -split "/")[-1]
        $this.ResourceType = "Microsoft.Authorization/roleAssignments"
    }
}

function New-AzOpsRoleAssignment {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [OutputType([AzOpsRoleAssignment])]
        [Parameter(Position = 0, ParameterSetName = "PSRoleAssignment", ValueFromPipeline = $true)]
        [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] $properties
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleAssignment" -Message ("Initiating function " + $MyInvocation.MyCommand + " Begin")
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleAssignment" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        return [AzOpsRoleAssignment]::new($properties)
    }
    end {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsRoleAssignment" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}


function Get-AzOpsRoleAssignmentAtScope {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Processing $scope"
        $currentRoleAssignmentsInAzure = @()
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Retrieving Role Assignment at Scope $scope"

        foreach ($roleAssignment in (Get-AzRoleAssignment -Scope $scope | Where-Object -FilterScript { $_.Scope -eq $scope })) {
            $currentRoleAssignmentsInAzure += New-AzOpsRoleAssignment -properties $roleAssignment
        }
        #$currentRoleAssignmentsInAzure = ((Invoke-AzRestMethod -Path "$scope/providers/Microsoft.Authorization/roleAssignments?api-version=2018-09-01-preview" -Method GET).Content | ConvertFrom-Json -Depth 100).value.properties | Where-Object -FilterScript { $_.Scope -eq $scope }
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Retrieved Role Assignment at Scope - Total Count $($currentRoleAssignmentsInAzure.count)"

        return $currentRoleAssignmentsInAzure
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Finished Processing $scope"
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsRoleAssignmentAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}