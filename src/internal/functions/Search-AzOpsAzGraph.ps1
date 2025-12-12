function Search-AzOpsAzGraph {

    <#
        .SYNOPSIS
            Search Graph based on input query combined with scope ManagementGroupName or Subscription Id.
            Manages paging of results, ensuring completeness of results.
        .PARAMETER UseTenantScope
            Use Tenant as Scope true or false
        .PARAMETER ManagementGroupName
            ManagementGroup Id
        .PARAMETER Subscription
            Subscription object(s) containing subscription information. Can be a single object or array of objects.
            Each object must have an 'Id' property with a valid GUID.
            Example structure:
            @{
                "Name" = "MySubscription"
                "Id" = "1ea96474-9e13-442f-afe3-b2e7810e6rb8"
                "Type" = "/subscriptions"
            }
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
        [ValidateScript({
            # Allow null input
            if ($null -eq $_) { return $true }
            # Convert single object to array for uniform processing
            $subscriptions = if ($_ -is [array]) { $_ } else { @($_) }
            foreach ($sub in $subscriptions) {
                # Validate Id property exists
                if (-not ($sub.PSObject.Properties.Name -contains 'Id')) {
                    throw "Subscription Id is missing: [$sub]"
                }
                # Validate Id is a valid GUID
                if (-not ($sub.Id -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
                    throw "Subscription Id must be a valid GUID format: [$sub]"
                }
            }
            return $true
        })]
        [object]
        $Subscription,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $Query
    )

    process {
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing' -LogStringValues $Query
        $results = [System.Collections.Generic.List[object]]::new()

        if ($UseTenantScope) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.UseTenantScope'
            try {
                do {
                    $tenantProcessing = Search-AzGraph -UseTenantScope -Query $Query -AllowPartialScope -SkipToken $tenantProcessing.SkipToken -ErrorAction Stop
                    if ($tenantProcessing) { $results.AddRange($tenantProcessing) }
                }
                while ($tenantProcessing.SkipToken)
            }
            catch {
                Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.UseTenantScope.Failed' -LogStringValues $Query, $_.Exception.Message
            }
        }

        if ($ManagementGroupName) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.ManagementGroup' -LogStringValues $ManagementGroupName
            try {
                do {
                    $mgProcessing = Search-AzGraph -ManagementGroup $ManagementGroupName -Query $Query -AllowPartialScope -SkipToken $mgProcessing.SkipToken -ErrorAction Stop
                    if ($mgProcessing) { $results.AddRange($mgProcessing) }
                }
                while ($mgProcessing.SkipToken)
            }
            catch {
                Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.ManagementGroup.Failed' -LogStringValues $Query, $ManagementGroupName, $_.Exception.Message
            }
        }

        if ($Subscription) {
            # Create a counter, set the batch size, and prepare a variable for the results
            $counter = [PSCustomObject] @{ Value = 0 }
            $batchSize = 1000
            # Group subscriptions into batches to conform with graph limits
            $subscriptionBatch = $Subscription | Group-Object -Property { [math]::Floor($counter.Value++ / $batchSize) }
            foreach ($group in $subscriptionBatch) {
                $subscriptionIds = ($group.Group).Id -join ', '
                $subscriptionCount = $group.Group.Count
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.SubscriptionBatch' -LogStringValues $subscriptionCount, $subscriptionIds
                try {
                    $batchProcessing = $null
                    do {
                        $batchProcessing = Search-AzGraph -Subscription ($group.Group).Id -Query $Query -SkipToken $batchProcessing.SkipToken -ErrorAction Stop
                        if ($batchProcessing) { $results.AddRange($batchProcessing) }
                    }
                    while ($batchProcessing.SkipToken)
                }
                catch {
                    # Batch failed - try each subscription individually to identify the problematic scope
                    Write-AzOpsMessage -LogLevel Warning -LogString 'Search-AzOpsAzGraph.Processing.SubscriptionBatch.Failed' -LogStringValues $subscriptionIds, $_.Exception.Message
                    Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.SubscriptionBatch.RetryIndividually' -LogStringValues $subscriptionCount
                    foreach ($sub in $group.Group) {
                        try {
                            Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.Subscription' -LogStringValues $sub.Name, $sub.Id
                            $subProcessing = $null
                            do {
                                $subProcessing = Search-AzGraph -Subscription $sub.Id -Query $Query -SkipToken $subProcessing.SkipToken -ErrorAction Stop
                                if ($subProcessing) { $results.AddRange($subProcessing) }
                            }
                            while ($subProcessing.SkipToken)
                        }
                        catch {
                            Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.Subscription.Failed' -LogStringValues $Query, $sub.Name, $sub.Id, $_.Exception.Message
                            try {
                                Write-AzOpsMessage -LogLevel Debug -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RetryWithRestApi' -LogStringValues $sub.Id
                                $resourceGraphApiVersion = (($script:AzOpsResourceProvider | Where-Object {$_.ProviderNamespace -eq 'Microsoft.ResourceGraph'}).ResourceTypes | Where-Object {$_.ResourceTypeName -eq 'queries'}).ApiVersions | Select-Object -First 1
                                $requestBody = @{
                                    subscriptions = @($sub.Id)
                                    query = $Query
                                } | ConvertTo-Json -Depth 10
                                $restApiResponse = $null
                                do {
                                    $response = Invoke-AzRestMethod -Method POST -Path "/providers/Microsoft.ResourceGraph/resources?api-version=$resourceGraphApiVersion" -Payload $requestBody -ErrorAction Stop
                                    if ($response.StatusCode -eq 200) {
                                        try {
                                            $restApiResponse = $response.Content | ConvertFrom-Json -Depth 100 -ErrorAction Stop
                                        }
                                        catch {
                                            # Fallback to hashtable for empty string property names
                                            try {
                                                $restApiResponse = $response.Content | ConvertFrom-Json -Depth 100 -AsHashtable -ErrorAction Stop
                                                # Validate response structure
                                                if (-not $restApiResponse.ContainsKey('data')) {
                                                    Write-AzOpsMessage -LogLevel Warning -LogString 'Search-AzOpsAzGraph.Processing.Subscription.InvalidRestApiResponse' -LogStringValues $requestBody, $_.Exception.Message
                                                    break
                                                }
                                                # Identify which resource caused the need for -AsHashtable
                                                if ($restApiResponse['data']) {
                                                    # Store skipToken before processing
                                                    $originalSkipToken = $restApiResponse['$skipToken']
                                                    $cleanData = [System.Collections.Generic.List[object]]::new()
                                                    foreach ($resource in $restApiResponse['data']) {
                                                        # Check if resource contains empty string keys by converting to JSON and checking
                                                        $resourceJson = $resource | ConvertTo-Json -Depth 100 -Compress
                                                        if ($resourceJson -match '"":\s*[^,}]') {
                                                            $id = $resource['id']
                                                            Write-AzOpsMessage -LogLevel Warning -LogString 'Search-AzOpsAzGraph.Processing.Subscription.EmptyStringKeyDetected' -LogStringValues $id
                                                            # Skip this resource - don't add it to cleaned data
                                                            continue
                                                        }
                                                        # Add valid resources to the cleaned list
                                                        $cleanData.Add($resource)
                                                    }
                                                    # Convert hashtable back to PSCustomObject structure
                                                    $restApiResponse = [PSCustomObject]@{
                                                        data = $cleanData | ForEach-Object { $_ | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 }
                                                        totalRecords = $restApiResponse['totalRecords']
                                                        count = $cleanData.Count
                                                        facets = $restApiResponse['facets']
                                                    }

                                                    # Restore skipToken if it existed
                                                    if ($originalSkipToken) {
                                                        $restApiResponse | Add-Member -MemberType NoteProperty -Name '$skipToken' -Value $originalSkipToken
                                                    }
                                                }
                                            }
                                            catch {
                                                Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.Subscription.JsonParseFailed' -LogStringValues $Query, $sub.Id, $_.Exception.Message
                                                # Skip to next subscription
                                            }
                                        }
                                        if ($restApiResponse.data) {
                                            Write-AzOpsMessage -LogLevel Verbose -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RestApiSuccess' -LogStringValues $sub.Id, $restApiResponse.data.Count
                                            $results.AddRange($restApiResponse.data)
                                        }
                                        # Prepare next page request if skipToken exists
                                        if ($restApiResponse.'$skipToken') {
                                            $requestBody = @{
                                                subscriptions = @($sub.Id)
                                                query = $Query
                                                options = @{
                                                    '$skipToken' = $restApiResponse.'$skipToken'
                                                }
                                            } | ConvertTo-Json -Depth 10
                                        }
                                    }
                                    else {
                                        # Log the raw error response for analysis
                                        Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RestApiFailed' -LogStringValues $sub.Id, $response.StatusCode, $response.Content
                                        # Attempt to parse error details
                                        try {
                                            $errorContent = $response.Content | ConvertFrom-Json -ErrorAction Stop
                                            if ($errorContent.error) {
                                                Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RestApiErrorDetails' -LogStringValues $errorContent.error.code, $errorContent.error.message
                                            }
                                        }
                                        catch {
                                            Write-AzOpsMessage -LogLevel Debug -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RestApiRawError' -LogStringValues $response.Content
                                        }
                                        # Break pagination loop on error
                                        break
                                    }
                                } while ($restApiResponse.'$skipToken')
                            }
                            catch {
                                # Log REST API fallback error but continue processing other subscriptions
                                Write-AzOpsMessage -LogLevel Error -LogString 'Search-AzOpsAzGraph.Processing.Subscription.RestApiException' -LogStringValues $Query, $sub.Id, $_.Exception.Message
                            }
                            # Continue processing remaining subscriptions in the group
                        }
                    }
                }
            }
        }

        if ($results) {
            $providerLookup = @{}
            foreach ($ResourceProvider in $script:AzOpsResourceProvider) {
                foreach ($ResourceTypeName in $ResourceProvider.ResourceTypes.ResourceTypeName) {
                    # Use lowercase key for case-insensitive matching
                    $key = "$($ResourceProvider.ProviderNamespace)/$ResourceTypeName".ToLower([System.Globalization.CultureInfo]::InvariantCulture)
                    $providerLookup[$key] = @{
                        Namespace = $ResourceProvider.ProviderNamespace
                        TypeName = $ResourceTypeName
                    }
                }
            }

            $resultsType = [System.Collections.Generic.List[object]]::new()
            foreach ($result in $results) {
                # Add null check for result.type property
                if (-not $result.type) {
                    continue
                }
                # Process each graph result and normalize ProviderNamespace casing using hashtable lookup
                $resultTypeKey = $result.type.ToLower([System.Globalization.CultureInfo]::InvariantCulture)
                if ($providerLookup.ContainsKey($resultTypeKey)) {
                    # Reconstruct the type with correct casing from the lookup
                    $result.type = "$($providerLookup[$resultTypeKey].Namespace)/$($providerLookup[$resultTypeKey].TypeName)"
                    $resultsType.Add($result)
                }
            }
            Write-AzOpsMessage -LogLevel Debug -LogString 'Search-AzOpsAzGraph.Processing.Done' -LogStringValues $Query
            return $resultsType
        }
        else {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Search-AzOpsAzGraph.Processing.NoResult' -LogStringValues $Query
        }
    }

}