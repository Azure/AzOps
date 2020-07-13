<#
.SYNOPSIS
    The cmdlets tests if multiple Management Groups or subscriptions with name exists in global variables $global:AzOpsAzManagementGroup -and $global:AzOpsSubscription
.DESCRIPTION
    The cmdlets tests if multiple Management Groups or subscriptions with name exists in global variables $global:AzOpsAzManagementGroup -and $global:AzOpsSubscription.
    Since the function identifies this via the variables, it is a requirement that discover
.EXAMPLE
    Test-AzOpsDuplicateSubMgmtGroup
.INPUTS
    None
.OUTPUTS
    Returns [PSCustomObject[]] with the subscriptions or Management Groups that has duplicate displaynames including details.
    DuplicateName            Count Type            Ids
    -------------            ----- ----            ---
    FTE MSDN                     2 Subscription    {d1b20141-9278-4f34-903e-ed4ade39a4cc, 70636965-895a-46b7-932e-d8f52818a8fc}
    Production Subscriptions     2 ManagementGroup {/providers/Microsoft.Management/managementGroups/PRD, /providers/Microsoft.Management/managementGroups/PROD}
    Test                         2 ManagementGroup {/providers/Microsoft.Management/managementGroups/test, /providers/Microsoft.Management/managementGroups/testv2}
#>

# The following SuppressMessageAttribute entries are used to surpress
# PSScriptAnalyzer tests against known exceptions as per:
# https://github.com/powershell/psscriptanalyzer#suppressing-rules
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsAzManagementGroup')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSubscriptions')]
param ()

function Test-AzOpsDuplicateSubMgmtGroup {

    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        # Subscription object
        [Parameter(Mandatory = $false)]
        $Subscriptions = $global:AzOpsSubscriptions,
        # Management Group object
        [Parameter(Mandatory = $false)]
        $ManagementGroups = $global:AzOpsAzManagementGroup
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsDuplicateSubMgmtGroup" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        $DuplicateNames = @()
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsDuplicateSubMgmtGroup" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        # Iterate through all subscriptions and add the ones with duplicate names to [PSCustomObject]
        $DuplicateNames += $Subscriptions | Group-Object -Property Name | Where-Object { $_.Count -gt 1 } | ForEach-Object -Process {
            [PSCustomObject]@{
                DuplicateName = $_.Name
                Count         = $_.Count
                Type          = "Subscription"
                Ids           = $_.Group.Id
            }
        }
        # Iterate through all Management Groups and add the ones with duplicate names to [PSCustomObject]
        $DuplicateNames += $ManagementGroups | Group-Object -Property DisplayName | Where-Object { $_.Count -gt 1 } | ForEach-Object -Process {
            [PSCustomObject]@{
                DuplicateName = $_.Name
                Count         = $_.Count
                Type          = "ManagementGroup"
                Ids           = $_.Group.Id
            }
        }
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsDuplicateSubMgmtGroup" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
        # Return output if duplicate names exists
        if ($DuplicateNames) {
            return $DuplicateNames
        }
    }

}