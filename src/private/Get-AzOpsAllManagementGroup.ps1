<#
.SYNOPSIS
    The cmdlet will recursively enumerates a management group and returns all children
.DESCRIPTION
    The cmdlet will recursively enumerates a management group and returns all children mgs.
    If the $global:AzOpsSupportPartialMgDiscovery has been used, it will add all MG's where discovery should initiate to the AzOpsPartialRoot variable.
.EXAMPLE
    Get-AzOpsAllManagementGroup -ManagementGroup Tailspin
    Id                : /providers/Microsoft.Management/managementGroups/Tailspin
    Type              : /providers/Microsoft.Management/managementGroups
    Name              : Tailspin
    TenantId          : d4c7591d-9b0c-49a4-9670-5f0349b227f1
    DisplayName       : Tailspin
    UpdatedTime       : 0001-01-01 00:00:00
    UpdatedBy         :
    ParentId          : /providers/Microsoft.Management/managementGroups/d4c7591d-9b0c-49a4-9670-5f0349b227f1
    ParentName        : d4c7591d-9b0c-49a4-9670-5f0349b227f1
    ParentDisplayName : Tenant Root Group
.INPUTS
    ManagementGroupName
.PARAMETER ManagementGroup
    Name of the management group to enumerate
.OUTPUTS
    Management Group Object
#>
function Get-AzOpsAllManagementGroup {

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsPartialRoot')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSupportPartialMgDiscovery')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { Get-AzManagementGroup -GroupId $_ -WarningAction SilentlyContinue } )]
        $ManagementGroup
    )
    begin {

    }
    process {
        $MG = Get-AzManagementGroup -GroupId $ManagementGroup -Expand -Recurse -WarningAction SilentlyContinue
        if (1 -eq $global:AzOpsSupportPartialMgDiscovery) {
            if ($MG.ParentId -and -not(Get-AzManagementGroup -GroupId $MG.ParentName -ErrorAction Ignore -WarningAction SilentlyContinue)) {
                $global:AzOpsPartialRoot += $MG
            }
            if ($MG.Children) {
                $MG.Children | where-object { $_.Type -eq "/providers/Microsoft.Management/managementGroups" } | Foreach-Object -Process {
                    Get-AzOpsAllManagementGroup -ManagementGroup $_.Name
                }
            }
            return $MG
        }
        else {
            return $MG
        }
    }
    end {

    }


}