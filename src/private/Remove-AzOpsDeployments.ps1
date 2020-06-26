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
            Write-Verbose "$(Get-Date) Removing Deployment $($_.Id)"
            Remove-AzTenantDeployment -DeploymentName $_.DeploymentName
        }

        Get-AzManagementGroup   | Foreach-Object -Parallel {
            Get-AzManagementGroupDeployment -ManagementGroupId $_.Name |  Foreach-Object -Parallel {
                Write-Verbose "$(Get-Date) Removing Deployment $($_.Id)"
                Remove-AzManagementGroupDeployment -DeploymentName $_.DeploymentName -ManagementGroupId $_.ManagementGroupId
            }
        }

        Get-AzSubscription | ForEach-Object {
            Set-AzContext -SubscriptionId $_.SubscriptionId | out-null
            Get-AzSubscriptionDeployment |  Foreach-Object -Parallel {
                Write-Verbose "$(Get-Date) Removing Deployment $($_.Id)"
                Remove-AzSubscriptionDeployment -Id $_.Id
            }
        }
    }
    end {}
}