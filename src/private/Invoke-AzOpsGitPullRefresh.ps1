function Invoke-AzOpsGitPullRefresh {

    [CmdletBinding()]
    param ()

    begin {
        $skipResourceGroup = $env:AZOPS_SKIP_RESOURCE_GROUP
        $skipPolicy = $env:AZOPS_SKIP_POLICY
    }

    process {
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy
    }

    end {}

}
