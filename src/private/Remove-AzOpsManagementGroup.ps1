<#
.SYNOPSIS
    This cmdlets removes Management Group and all its children recursively and moves any Subscription found in hierarchy to root Management Group.
.DESCRIPTION
    This cmdlets removes Management Group and all its children recursively and moves any Subscription found in hierarchy to root Management Group.
.EXAMPLE
    # Discover all custom policy definitions deployed at Management Group scope
    Remove-AzOpsManagementGroup -groupName ES -Verbose
.INPUTS
    GroupName
.OUTPUTS
    None.
#>
function Remove-AzOpsManagementGroup {

    [CmdletBinding(SupportsShouldProcess = $true)]
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
        if ($ChildManagementGroups -and $PSCmdlet.ShouldProcess("Remove Management Group(s) $($ChildManagementGroups.Name.foreach({'['+$_+']'}) -join ' ')?")) {
            foreach ($Child in $ChildManagementGroups) {
                if ($Child.Type -eq '/subscriptions') {
                    Write-AzOpsLog -Level Verbose -Topic "Remove-AzOpsManagementGroup" -Message "Moving Subscription $($Child.Name) under Root Management Group $RootManagementGroupName"
                    New-AzManagementGroupSubscription -GroupName $RootManagementGroupName -SubscriptionId $Child.Name
                }
                else {
                    Write-AzOpsLog -Level Verbose -Topic "Remove-AzOpsManagementGroup" -Message "Removing Management Group - $($Child.Name)"
                    Remove-AzOpsManagementGroup -GroupName $Child.Name -RootManagementGroupName $RootManagementGroupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 
                }
            }
        }
        Write-AzOpsLog -Level Verbose -Topic "Remove-AzOpsManagementGroup" -Message "Removing Management Group - $($groupName)"
        Remove-AzManagementGroup -GroupName $GroupName -WarningAction SilentlyContinue
    }

    end {}

}
