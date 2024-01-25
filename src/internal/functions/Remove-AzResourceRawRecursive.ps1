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
            Parameter to track item processing and return result.
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
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRawRecursive.Processing' -LogStringValues $item.ScopeObject.resource, $item.FullyQualifiedResourceId
                    # Attempt to remove the resource
                    $result = Remove-AzResourceRaw -FullyQualifiedResourceId $item.FullyQualifiedResourceId -ScopeObject $item.ScopeObject -TemplateFilePath $item.TemplateFilePath -TemplateParameterFilePath $item.TemplateParameterFilePath
                    if ($result.Status -eq 'failed' -and $result.FullyQualifiedResourceId -notin $OutputObject.FullyQualifiedResourceId){
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
                    if ($item.FullyQualifiedResourceId -in $OutputObject.FullyQualifiedResourceId) {
                        foreach ($output in $OutputObject) {
                            if ($output.FullyQualifiedResourceId -eq $item.FullyQualifiedResourceId -and $output.Status -eq 'failed') {
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