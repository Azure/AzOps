function Remove-AzOpsTestsDeployment {

    <#
        .SYNOPSIS
            Assist in removal of AzOps Test Deployments, destructive command removes resources in the context executed.
        .DESCRIPTION
            Assist in removal of AzOps Test Deployments, destructive command removes resources in the context executed.
        .EXAMPLE
            > Remove-AzOpsTestsDeployment -CleanupEnvironment:$true
    #>

    [CmdletBinding()]
    param (
        $cleanupEnvironment = $false
    )

    process {
        if ($CleanupEnvironment) {
            function Remove-ManagementGroups {

                param (
                    [Parameter()]
                    [string]
                    $DisplayName,

                    [Parameter()]
                    [string]
                    $Name,

                    [Parameter()]
                    [string]
                    $RootName
                )

                process {
                    # Retrieve list of children within the provided Management Group Id
                    $children = (Get-AzManagementGroup -GroupId $Name -Expand -Recurse -WarningAction SilentlyContinue).Children
                    if ($children) {
                        $children | ForEach-Object {
                            if ($_.Type -eq "Microsoft.Management/managementGroups") {
                                # Invoke function again with Child resources
                                Write-PSFMessage -Level Verbose -Message "Nested Management Group: $($DisplayName)" -FunctionName "Remove-AzOpsTestsDeployment"
                                Remove-ManagementGroups -DisplayName $_.DisplayName -Name $_.Name -RootName $RootName
                            }
                            if ($_.Type -eq '/subscriptions') {
                                # Move Subscription resource to Tenant Root Group
                                Write-PSFMessage -Level Verbose -Message "Moving Subscription: $($_.Name)" -FunctionName "Remove-AzOpsTestsDeployment"
                                $null = New-AzManagementGroupSubscription -GroupId $RootName -SubscriptionId $_.Name -WarningAction SilentlyContinue
                            }
                        }
                    }
                    Write-PSFMessage -Level Verbose -Message "Removing Management Group: $($DisplayName)" -FunctionName "Remove-AzOpsTestsDeployment"
                    Remove-AzManagementGroup -GroupId $Name -Confirm:$false -WarningAction SilentlyContinue
                }

            }
            #region cleanupEnvironment
            try {
                Write-PSFMessage -Level Verbose -Message "Executing test cleanup" -FunctionName "Remove-AzOpsTestsDeployment"
                # Cleanup managementGroups
                $script:managementGroups = Get-AzManagementGroup | Where-Object {$_.DisplayName -eq "Test" -or $_.DisplayName -eq "AzOpsMGMTName"}
                foreach ($script:mgclean in $script:managementGroups) {
                    Remove-ManagementGroups -DisplayName $script:mgclean.DisplayName -Name $script:mgclean.Name -RootName (Get-AzTenant).TenantId
                }
                # Collect resources to cleanup
                Get-AzResourceLock | Remove-AzResourceLock -Force
                $script:resourceGroups = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -like "*-azopsrg"}
                $script:roleAssignments = Get-AzRoleAssignment | Where-Object {$_.Scope -ne "/"}
                $script:policyAssignments = Get-AzPolicyAssignment
                $script:policyDefinitions = Get-AzPolicyDefinition -Custom
                $script:policySetDefinitions = Get-AzPolicySetDefinition -Custom
                $script:policyExemptions = Get-AzPolicyExemption -ErrorAction SilentlyContinue
                # Cleanup resourceGroups
                $script:resourceGroups | ForEach-Object -ThrottleLimit 20 -Parallel {
                    Write-PSFMessage -Level Verbose -Message "Executing test resourceGroups cleanup thread of $($_.ResourceGroupName)" -FunctionName "Remove-AzOpsTestsDeployment"
                    $script:run = $_ | Remove-AzResourceGroup -Confirm:$false -Force
                }
                # Cleanup roleAssignments and policyAssignments
                $script:roleAssignments | Remove-AzRoleAssignment -Confirm:$false -ErrorAction SilentlyContinue
                $script:policyExemptions | Remove-AzPolicyExemption -Force -Confirm:$false -ErrorAction SilentlyContinue
                $script:policyAssignments | Remove-AzPolicyAssignment -Confirm:$false -ErrorAction SilentlyContinue
                $script:policyDefinitions | Remove-AzPolicyDefinition -Force -Confirm:$false -ErrorAction SilentlyContinue
                $script:policySetDefinitions | Remove-AzPolicySetDefinition -Force -Confirm:$false -ErrorAction SilentlyContinue
                # Collect and cleanup deployment jobs
                $azTenantDeploymentJobs = Get-AzTenantDeployment
                $azTenantDeploymentJobs | ForEach-Object -ThrottleLimit 10 -Parallel {
                    Write-PSFMessage -Level Verbose -Message "Executing test AzDeployment cleanup thread of $($_.DeploymentName)" -FunctionName "Remove-AzOpsTestsDeployment"
                    $_ | Remove-AzTenantDeployment -Confirm:$false
                }
                Get-AzManagementGroupDeployment -ManagementGroupId "cd35e23c-537f-4553-a280-f5a60033a446" | Remove-AzManagementGroupDeployment -Confirm:$false
                $azDeploymentJobs = Get-AzDeployment
                $azDeploymentJobs | ForEach-Object -ThrottleLimit 10 -Parallel {
                    Write-PSFMessage -Level Verbose -Message "Executing test AzDeployment cleanup thread of $($_.DeploymentName)" -FunctionName "Remove-AzOpsTestsDeployment"
                    $_ | Remove-AzDeployment -Confirm:$false
                }
            }
            catch {
                Write-PSFMessage -Level Warning -Message $_ -FunctionName "Remove-AzOpsTestsDeployment"
            }
            #endregion cleanupEnvironment
        }
    }
}