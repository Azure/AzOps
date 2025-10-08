function Get-AzOpsNestedSubscription {
    <#
        .SYNOPSIS
            Create a list of subscriptionId's nested at ManagementGroup Scope
        .PARAMETER Scope
            ManagementGroup Name
        .PARAMETER SkipSubscription
            Filter which Subscription IDs should be excluded from pull.
        .EXAMPLE
            > Get-AzOpsNestedSubscription -Scope 5663f39e-feb1-4303-a1f9-cf20b702de61
            Discover subscriptions at Management Group scope and below
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $Scope,

        [string[]]
        $SkipSubscription = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipSubscription')
    )

    process {
        $children = ($script:AzOpsAzManagementGroup | Where-Object {$_.Name -eq $Scope}).Children
        if ($children) {
            $subscriptionIds = @()
            foreach ($child in $children) {
                if (($child.Type -eq '/subscriptions') -and ($script:AzOpsSubscriptions.id -contains $child.Id) -and ($child.Name -notin $SkipSubscription)) {
                    $subscriptionIds += [PSCustomObject] @{
                        Name = $child.DisplayName
                        Id = $child.Name
                        Type = $child.Type
                    }
                }
                else {
                    $subscriptionIds += Get-AzOpsNestedSubscription -Scope $child.Name
                }
            }
            if ($subscriptionIds) {
                return $subscriptionIds
            }
        }
    }
}