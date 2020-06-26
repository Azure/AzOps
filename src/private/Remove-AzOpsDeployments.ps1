<#
.SYNOPSIS
    This cmdlets removes all Deployments.
.DESCRIPTION
    This cmdlets removes all Deployments.
.EXAMPLE
    Remove-AzOpsDeployments
.INPUTS
    None.
.OUTPUTS
    None.
#>
function Remove-AzOpsDeployments {
    [CmdletBinding()]
    param()

    begin {
        if (-not $rootManagementGroupName) {
            $rootManagementGroupName = (Get-AzManagementGroup | Where-Object -FilterScript { $_.Name -eq (Get-AzContext).Tenant.Id }).Name
        }
    }

    process {
        Get-AzTenantDeployment   | Foreach-Object -Parallel {
            Write-Verbose "$(Get-Date) Removing Tenant Deployment $($_.Id)"
            Stop-AzTenantDeployment -Id $_.Id -Confirm:$false -ErrorAction:SilentlyContinue
            Remove-AzTenantDeployment -Id $_.Id
        }

        Get-AzManagementGroup   | Foreach-Object -Parallel {
            Get-AzManagementGroupDeployment -ManagementGroupId $_.Name |  Foreach-Object -Parallel {
                Write-Verbose "$(Get-Date) Removing Management Group Deployment $($_.Id)"
                Stop-AzManagementGroupDeployment -Id $_.Id -Confirm:$false -ErrorAction:SilentlyContinue
                Remove-AzManagementGroupDeployment -Id $_.Id
            }
        }

        Get-AzSubscription | ForEach-Object {
            Set-AzContext -SubscriptionId $_.SubscriptionId | out-null
            Get-AzSubscriptionDeployment |  Foreach-Object -Parallel {
                Write-Verbose "$(Get-Date) Removing Subscription Deployment $($_.Id)"
                Stop-AzSubscriptionDeployment -Id $_.Id -Confirm:$false -ErrorAction:SilentlyContinue
                Remove-AzSubscriptionDeployment -Id $_.Id
            }
        }
    }
    end {}
}