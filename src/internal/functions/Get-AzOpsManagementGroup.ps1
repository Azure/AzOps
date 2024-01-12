function Get-AzOpsManagementGroup {

    <#
        .SYNOPSIS
            The cmdlet will recursively enumerates a management group and returns all children
        .DESCRIPTION
            The cmdlet will recursively enumerates a management group and returns all children mgs.
            If the -PartialDiscovery parameter has been used, it will add all MG's where discovery should initiate to the AzOpsPartialRoot variable.
        .PARAMETER ManagementGroup
            Name of the management group to enumerate
        .PARAMETER PartialDiscovery
            Whether to recursively grab all Management Groups and add them to the partial root cache
        .EXAMPLE
            Get-AzOpsManagementGroup -ManagementGroup Tailspin
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
        .OUTPUTS
            Management Group Object
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ManagementGroup,

        [switch]
        $PartialDiscovery
    )

    process {
        try {
            $groupObject = Get-AzManagementGroup -GroupId $ManagementGroup -Expand -WarningAction SilentlyContinue
        }
        catch {
            Write-AzOpsMessage -LogLevel Error -LogString 'Get-AzOpsManagementGroup.Failed' -LogStringValues $ManagementGroup
            throw
        }
        if ($PartialDiscovery) {
            if ($groupObject.ParentId -and -not (Get-AzManagementGroup -GroupId $groupObject.ParentName -ErrorAction Ignore -WarningAction SilentlyContinue)) {
                $script:AzOpsPartialRoot += $groupObject
            }
            if ($groupObject.Children) {
                $groupObject.Children | Where-Object Type -eq "Microsoft.Management/managementGroups" | Foreach-Object -Process {
                    Get-AzOpsManagementGroup -ManagementGroup $_.Name -PartialDiscovery:$PartialDiscovery
                }
            }
        }
        return $groupObject
    }

}