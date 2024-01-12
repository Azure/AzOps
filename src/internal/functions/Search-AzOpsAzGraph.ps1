function Search-AzOpsAzGraph {

    <#
        .SYNOPSIS
            Search Graph based on input query combined with scope ManagementGroupName or Subscription Id.
            Manages paging of results, ensuring completeness of results.
        .PARAMETER UseTenantScope
            Use Tenant as Scope true or false
        .PARAMETER ManagementGroupName
            ManagementGroup Name
        .PARAMETER Subscription
            Subscription Id's
        .PARAMETER Query
            AzureResourceGraph-Query
        .EXAMPLE
            > Search-AzOpsAzGraph -ManagementGroupName "5663f39e-feb1-4303-a1f9-cf20b702de61" -Query "policyresources | where type == 'microsoft.authorization/policyassignments'"
            Discover all policy assignments deployed at Management Group scope and below
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $UseTenantScope,
        [Parameter(Mandatory = $false)]
        [string]
        $ManagementGroupName,
        [Parameter(Mandatory = $false)]
        [object]
        $Subscription,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $Query
    )

    process {
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing' -LogStringValues $Query
        $results = @()
        if ($UseTenantScope) {
            do {
                $processing = Search-AzGraph -UseTenantScope -Query $Query -AllowPartialScope -SkipToken $processing.SkipToken -ErrorAction Stop
                $results += $processing
            }
            while ($processing.SkipToken)
        }
        if ($ManagementGroupName) {
            do {
                $processing = Search-AzGraph -ManagementGroup $ManagementGroupName -Query $Query -AllowPartialScope -SkipToken $processing.SkipToken -ErrorAction Stop
                $results += $processing
            }
            while ($processing.SkipToken)
        }
        if ($Subscription) {
            # Create a counter, set the batch size, and prepare a variable for the results
            $counter = [PSCustomObject] @{ Value = 0 }
            $batchSize = 1000
            # Group subscriptions into batches to conform with graph limits
            $subscriptionBatch = $Subscription | Group-Object -Property { [math]::Floor($counter.Value++ / $batchSize) }
            foreach ($group in $subscriptionBatch) {
                do {
                    $processing = Search-AzGraph -Subscription ($group.Group).Id -Query $Query -SkipToken $processing.SkipToken -ErrorAction Stop
                    $results += $processing
                }
                while ($processing.SkipToken)
            }
        }
        if ($results) {
            $resultsType = @()
            foreach ($result in $results) {
                # Process each graph result and normalize ProviderNamespace casing
                foreach ($ResourceProvider in $script:AzOpsResourceProvider) {
                    if ($ResourceProvider.ProviderNamespace -eq $result.type.Split('/')[0]) {
                        foreach ($ResourceTypeName in $ResourceProvider.ResourceTypes.ResourceTypeName) {
                            if ($ResourceTypeName -eq $result.type.Split('/')[1]) {
                                $result.type = ($result.type).replace($result.type.Split('/')[0],$ResourceProvider.ProviderNamespace)
                                $result.type = ($result.type).replace($result.type.Split('/')[1],$ResourceTypeName)
                                $resultsType += $result
                                break
                            }
                        }
                        break
                    }
                }
            }
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.Done' -LogStringValues $Query
            return $resultsType
        }
        else {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Search-AzOpsAzGraph.Processing.NoResult' -LogStringValues $Query
        }
    }

}