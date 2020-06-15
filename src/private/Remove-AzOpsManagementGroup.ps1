<#
.SYNOPSIS
    This cmdlets removes management group and all its children recursively and moves any subscription found in hierarchy to root management group.
.DESCRIPTION
    This cmdlets removes management group and all its children recursively and moves any subscription found in hierarchy to root management group.
.EXAMPLE
    #Discover all custom policy definitions deployed at management group scope
    Remove-AzOpsManagementGroup -groupName ES -Verbose
.INPUTS
    GroupName
.OUTPUTS
    None.
#>
function Remove-AzOpsManagementGroup {

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$GroupName,
        [Parameter()]
        [string]$RootManagementGroupName
    )

    begin {
        if (-not $rootManagementGroupName) {
            $rootManagementGroupName = (Get-AzManagementGroup | Where-Object -FilterScript { $_.Name -eq (Get-AzContext).Tenant.Id }).Name
        }
    }

    process {
        $ChildManagementGroups = (Get-AzManagementGroup -GroupName $GroupName -Expand -Recurse).Children
        if ($ChildManagementGroups) {
            foreach ($Child in $ChildManagementGroups) {
                if ($Child.Type -eq '/subscriptions') {
                    Write-Information "Moving Subscription $($Child.Name) under Root Management Group $RootManagementGroupName"
                    New-AzManagementGroupSubscription -GroupName $RootManagementGroupName -SubscriptionId $Child.Name
                }
                else {
                    Write-Verbose "Removing Management Group - $($Child.Name)"
                    Remove-AzOpsManagementGroup -GroupName $Child.Name -RootManagementGroupName $RootManagementGroupName -ErrorAction SilentlyContinue
                }

            }
        }
        Write-Verbose "Removing Management Group - $($groupName)"
        Remove-AzManagementGroup -GroupName $groupName
    }

    end {}

}
