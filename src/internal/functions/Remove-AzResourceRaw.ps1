function Remove-AzResourceRaw {

    <#
        .SYNOPSIS
            Performs resource deletion in Azure at any scope.
        .DESCRIPTION
            Performs resource deletion in Azure with FullyQualifiedResourceId and ScopeObject.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the parameters of the ARM templates can be found.
        .PARAMETER ScopeObject
            Resource to delete.
        .PARAMETER InputObject
            Object containing items for processing, used in combination with parameter Recursive.
        .PARAMETER Recursive
            If specified, performs recursive resource deletion and requires use of parameter InputObject.
        .EXAMPLE
            > Remove-AzResourceRaw -ScopeObject $ScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
            Name                           Value
            ----                           -----
            TemplateFilePath               /root/managementgroup/subscription/resourcegroup/template.json
            TemplateParameterFilePath      /root/managementgroup/subscription/resourcegroup/template.parameters.json
            ScopeObject                    ScopeObject
            Status                         success

            > Remove-AzResourceRaw -InputObject $retry -Recursive
            Name                           Value
            ----                           -----
            TemplateFilePath               /root/managementgroup/subscription/resourcegroup/template.json
            TemplateParameterFilePath      /root/managementgroup/subscription/resourcegroup/template.parameters.json
            ScopeObject                    ScopeObject
            Status                         success
    #>

    [CmdletBinding()]
    param (
        [string]
        $TemplateFilePath,
        [string]
        $TemplateParameterFilePath,
        [AzOpsScope]
        $ScopeObject,
        [array]
        $InputObject,
        [switch]
        $Recursive
    )

    process {
        function Remove-AzResourceRawRecursive {

            <#
                .SYNOPSIS
                    Performs recursive resource deletion in Azure at any scope.
                .DESCRIPTION
                    Takes $InputObject and performs recursive resource deletion in Azure and exhaust any permutation.
                .PARAMETER InputObject
                    Parameter containing items for processing.
                .PARAMETER CurrentOrder
                    Internal parameter to track recursive progress.
                .PARAMETER OutputObject
                    Track item processing and return result.
                .EXAMPLE
                    > $successFullItems, $failedItems = Remove-AzResourceRawRecursive -InputObject $retry
                    Example of a $retry array with 6 items, the number of permutations will be 6×5×4×3×2×1=720
            #>

            [CmdletBinding()]
            param (
                [array]
                $InputObject,
                [array]
                $CurrentOrder = @(),
                [array]
                $OutputObject = @()
            )

            process {
                if ($InputObject.Count -eq 0) {
                    # Base case: All items have been used, perform action on the current order
                    foreach ($item in $CurrentOrder) {
                        if ($item.Status -eq 'failed' -or $null -eq $item.Status) {
                            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRawRecursive.Processing' -LogStringValues $item.ScopeObject.Resource, $item.ScopeObject.Scope
                            # Attempt to remove the resource
                            $result = Remove-AzResourceRaw -ScopeObject $item.ScopeObject -TemplateFilePath $item.TemplateFilePath -TemplateParameterFilePath $item.TemplateParameterFilePath
                            if ($result.Status -eq 'failed' -and $result.ScopeObject.Scope -notin $OutputObject.ScopeObject.Scope){
                                # Add failed result to the output object
                                $OutputObject += $result
                            }
                        }
                    }
                    # Return the final result
                    return $OutputObject
                }
                else {
                    if ($InputObject -and $OutputObject) {
                        # Filter out items already processed successfully
                        $filteredOutputObject = @()
                        foreach ($item in $InputObject) {
                            if ($item.ScopeObject.Scope -in $OutputObject.ScopeObject.Scope) {
                                foreach ($output in $OutputObject) {
                                    if ($output.ScopeObject.Scope -eq $item.ScopeObject.Scope -and $output.Status -eq 'failed') {
                                        # Add previously failed item to the filtered output
                                        $filteredOutputObject += $output
                                        continue
                                    }
                                }
                            }
                        }
                        if ($filteredOutputObject) {
                            $InputObject = $filteredOutputObject
                        }
                    }
                    # Recursive case: Try each item in the current position and recurse with the remaining items
                    foreach ($item in $InputObject) {
                        $remainingItems = $InputObject -ne $item
                        $newOrder = $CurrentOrder + $item
                        # Recursively call Remove-AzResourceRawRecursive
                        $OutputObject = Remove-AzResourceRawRecursive -InputObject $remainingItems -CurrentOrder $newOrder -OutputObject $OutputObject
                    }
                    # Return the output after all permutations
                    return $OutputObject
                }
            }
        }
        function Get-AzOpsDeploymentStackActionOnUnmanage {
            param (
                [string]
                $ResourcesCleanupAction,
                [string]
                $ResourceGroupsCleanupAction,
                [string]
                $ManagementGroupsCleanupAction
            )

            # Check for deleteAll pattern
            if ($ResourcesCleanupAction -eq 'delete' -and
                $ResourceGroupsCleanupAction -eq 'delete' -and
                $ManagementGroupsCleanupAction -eq 'delete') {
                return 'deleteAll'
            }

            # Check for deleteResources pattern
            if ($ResourcesCleanupAction -eq 'delete' -and
                $ResourceGroupsCleanupAction -eq 'detach' -and
                $ManagementGroupsCleanupAction -eq 'detach') {
                return 'deleteResources'
            }

            # Check for detachAll pattern
            if ($ResourcesCleanupAction -eq 'detach' -and
                $ResourceGroupsCleanupAction -eq 'detach' -and
                $ManagementGroupsCleanupAction -eq 'detach') {
                return 'detachAll'
            }

            # Default fallback
            return 'detachAll'
        }
        if ($null -ne $InputObject -and $Recursive) {
            # Perform recursive resource deletion
            $result = Remove-AzResourceRawRecursive -InputObject $InputObject
            if ($result) {
                return $result
            }
            else {
                return
            }
        }
        elseif ($null -eq $InputObject -and $Recursive) {
            # Recursive resource deletion missing input
            Write-AzOpsMessage -LogLevel Error -LogString 'Remove-AzResourceRaw.Resource.Recursive.Missing'
            return
        }
        else {
            if (-not $ScopeObject) {
                # Resource deletion missing input
                Write-AzOpsMessage -LogLevel Error -LogString 'Remove-AzResourceRaw.Resource.Missing'
                return
            }
            # Construct result object
            $result = [PSCustomObject]@{
                TemplateFilePath = $TemplateFilePath
                TemplateParameterFilePath = $TemplateParameterFilePath
                ScopeObject = $ScopeObject
                Status = 'success'
            }
            # Check if the resource exists
            $resource = Get-AzOpsResource -ScopeObject $ScopeObject -ErrorAction SilentlyContinue
            # Remove the resource if it exists
            if ($resource) {
                try {
                    # Set Azure context for removal operation
                    Set-AzOpsContext -ScopeObject $ScopeObject
                    # Evaluate the resource type and perform the appropriate removal action
                    if ($ScopeObject.Resource -eq 'deploymentStacks') {
                        $actionOnUnmanage = Get-AzOpsDeploymentStackActionOnUnmanage -ResourcesCleanupAction $resource.resourcesCleanupAction -ResourceGroupsCleanupAction $resource.resourceGroupsCleanupAction -ManagementGroupsCleanupAction $resource.managementGroupsCleanupAction
                        if ($ScopeObject.ResourceGroup) {
                            $removeCommand = 'Remove-AzResourceGroupDeploymentStack'
                        }
                        elseif ($ScopeObject.Subscription) {
                            $removeCommand = 'Remove-AzSubscriptionDeploymentStack'
                        }
                        elseif ($scopeObject.ManagementGroup) {
                            $removeCommand = 'Remove-AzManagementGroupDeploymentStack'
                        }
                        Write-AzOpsMessage -LogLevel Verbose -LogString 'Remove-AzResourceRaw.Resource.StackCommand' -LogStringValues $removeCommand, $ScopeObject.Scope, $actionOnUnmanage
                        $null = & $removeCommand -ResourceId $ScopeObject.Scope -ActionOnUnmanage $actionOnUnmanage -Force -ErrorAction Stop
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Verbose -LogString 'Remove-AzResourceRaw.Resource.Command' -LogStringValues 'Remove-AzResource', $ScopeObject.Scope
                        $null = Remove-AzResource -ResourceId $ScopeObject.Scope -Force -ErrorAction Stop
                        $maxAttempts = 4
                        $attempt = 1
                        $gone = $false
                        while ($gone -eq $false -and $attempt -le $maxAttempts) {
                            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.CheckExistence' -LogStringValues $ScopeObject.Scope
                            Start-Sleep -Seconds 10
                            $tryResource = Get-AzOpsResource -ScopeObject $ScopeObject -ErrorAction SilentlyContinue
                            if (-not $tryResource) {
                                $gone = $true
                            }
                            $attempt++
                        }
                    }
                }
                catch {
                    # Log failure message
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.Failed' -LogStringValues $ScopeObject.Resource, $ScopeObject.Scope
                    $result.Status = 'failed'
                }
            }
            else {
                # Log not found message
                $result.Status = 'notfound'
            }
            # Return result object
            return $result
        }
    }
}