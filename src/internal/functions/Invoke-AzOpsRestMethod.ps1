function Invoke-AzOpsRestMethod {
    <#
        .SYNOPSIS
            Process Path with given Method and manage paging of results and returns value's
        .PARAMETER Path
            Path
        .PARAMETER Method
            Method
        .EXAMPLE
            > Invoke-AzOpsRestMethod -Path "/subscriptions/{subscription}/resourcegroups/{resourcegroup}/providers/microsoft.operationalinsights/workspaces/{workspace}?api-version={API}" -Method GET
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $Path,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Method
    )

    process {
        # Process Path with given Method
        Write-PSFMessage -Level Debug -String 'Invoke-AzOpsRestMethod.Processing' -StringValues $Path
        $allresults = do {
            try {
                $results = ((Invoke-AzRestMethod -Path $Path -Method $Method -ErrorAction Stop).Content | ConvertFrom-Json -Depth 100)
                $results.value
                $path = $results.nextLink -replace 'https://management\.azure\.com'
                if ($results.StatusCode -eq '429' -or $results.StatusCode -like '5*') {
                    $results.Headers.GetEnumerator() | ForEach-Object {
                        if ($_.key -eq 'Retry-After') {
                            Write-PSFMessage -Level Warning -String 'Invoke-AzOpsRestMethod.Processing.RateLimit' -StringValues $Path, $_.value
                            Start-Sleep -Seconds $_.value
                        }
                    }
                }
            }
            catch {
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsRestMethod.Processing.Warning' -StringValues $_, $Path
            }
        }
        while ($path)
        if ($allresults) {
            return $allresults
        }
    }
}