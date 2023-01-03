function Search-AzOpsAzGraph {
    <#
        .SYNOPSIS
            Search Graph based on input query combined with specific context for profile and scope.
            Manages paging of results, ensuring completes of results.
        .PARAMETER Context
            AzContext
        .PARAMETER Query
            AzureResourceGraph-Query
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Context,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $Query
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Search-AzOpsAzGraph.Processing' -StringValues $Query, $Context.Subscription.Id
        $results = @()
        $processing = Search-AzGraph -DefaultProfile $Context -Subscription $Context.Subscription.Id -Query $Query -ErrorAction Stop
        if ($processing) {
            $results += $processing
            do {
                if ($processing.SkipToken) {
                    Write-PSFMessage -Level Verbose -String 'Search-AzOpsAzGraph.Processing.Paging' -StringValues $Context.Subscription.Id
                    $processing = Search-AzGraph -DefaultProfile $Context -Subscription $Context.Subscription.Id -Query $Query -SkipToken $processing.SkipToken -ErrorAction Stop
                    $results += $processing
                }
                else {
                    $done = $true
                }
            } while ($done -ne $true)
        }
        if ($results) {
            Write-PSFMessage -Level Verbose -String 'Search-AzOpsAzGraph.Processing.Done' -StringValues $Query, $Context.Subscription.Id
            return $results
        }
    }
}