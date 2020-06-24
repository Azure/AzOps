function Invoke-AzOpsGitPullRefresh {

    [CmdletBinding()]
    param ()

    begin {
        if ($env:AZOPS_SKIP_RESOURCE_GROUP -eq "1") {
            $skipResourceGroup = $true
        }
        else {
            $skipResourceGroup = $false
        }
        if ($env:AZOPS_SKIP_POLICY -eq "1") {
            $skipPolicy = $true
        }
        else {
            $skipPolicy = $false
        }
    }

    process {
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy
    }

    end {}

}
