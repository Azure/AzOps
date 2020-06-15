<#
.SYNOPSIS
    The cmdlets tests if multiple management groups or subscriptions with name exists in global variables $global:AzOpsAzManagementGroup -and $Global:AzOpsSubscription
.DESCRIPTION
    The cmdlets tests if multiple management groups or subscriptions with name exists in global variables $global:AzOpsAzManagementGroup -and $Global:AzOpsSubscription.
    Since the function identifies this via the variables, it is a requirement that discover
.EXAMPLE
    Test-AzOpsDuplicateSubMgmtGroup
.INPUTS
    None
.OUTPUTS
    Returns [PSCustomObject[]] with the subscriptions or management groups that has duplicate displaynames including details.
    DuplicateName            Count Type            Ids
    -------------            ----- ----            ---
    FTE MSDN                     2 Subscription    {d1b20141-9278-4f34-903e-ed4ade39a4cc, 70636965-895a-46b7-932e-d8f52818a8fc}
    Production Subscriptions     2 ManagementGroup {/providers/Microsoft.Management/managementGroups/PRD, /providers/Microsoft.Management/managementGroups/PROD}
    Test                         2 ManagementGroup {/providers/Microsoft.Management/managementGroups/test, /providers/Microsoft.Management/managementGroups/testv2}
#>
function Test-AzOpsDuplicateSubMgmtGroup {
    
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        #Subscription object
        [Parameter(Mandatory = $false)]
        $Subscriptions = $global:AzOpsSubscriptions,
        #Management Group object
        [Parameter(Mandatory = $false)]
        $ManagementGroups = $global:AzOpsAzManagementGroup
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
    }
    
    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        $DuplicateNames = @()
        #Iterate through all subscriptions and add the ones with duplicate names to [PSCustomObject]
        $DuplicateNames += $Subscriptions | Group-Object -Property Name | Where-Object { $_.Count -gt 1 } | ForEach-Object -Process {
            [PSCustomObject]@{
                DuplicateName = $_.Name
                Count         = $_.Count
                Type          = "Subscription"
                Ids           = $_.Group.Id
            }
        }
        #Iterate through all management groups and add the ones with duplicate names to [PSCustomObject]
        $DuplicateNames += $ManagementGroups | Group-Object -Property DisplayName | Where-Object { $_.Count -gt 1 } | ForEach-Object -Process {
            [PSCustomObject]@{
                DuplicateName = $_.Name
                Count         = $_.Count
                Type          = "ManagementGroup"
                Ids           = $_.Group.Id
            }
        }
        #Return output if duplicate names exists
        return $DuplicateNames
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}