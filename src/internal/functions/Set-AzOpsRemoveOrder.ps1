function Set-AzOpsRemoveOrder {

    <#
        .SYNOPSIS
            Sorts a custom object list based on a specified priority order using a user-defined index.
        .DESCRIPTION
            Used to sort deletion priority, aka locks are removed prior to resource deletion attempts.
        .PARAMETER DeletionList
            Custom object list to be sorted based on the defined priority.
        .PARAMETER Index
            Script block that determines the index used for sorting the deletion list.
        .PARAMETER Priority
            Optional array of strings representing the priority order. Defaults to a predefined order if not provided.
        .EXAMPLE
            > $sortedList = Set-AzOpsRemoveOrder -DeletionList $myCustomObjectList -Index { $_.SomeProperty }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $DeletionList,
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Index,
        [string[]]
        $Priority = @(
            "locks",
            "policyExemptions",
            "policyAssignments",
            "policySetDefinitions",
            "policyDefinitions",
            "resourceGroups",
            "managementGroups"
        )
    )

    process {
        #Sort 'DeletionList' based on 'Priority'
        $deletionListSorted = $DeletionList | Sort-Object -Property {
            $resolvedIndex = & $Index
            $priorityIndex = $Priority.IndexOf($resolvedIndex)
            if ($priorityIndex -eq -1) {
                # Set a default priority for items not found in Priority
                return [int]::MaxValue
            }
            else {
                return $priorityIndex
            }
        }
        # Return processed list
        return $deletionListSorted
    }
}