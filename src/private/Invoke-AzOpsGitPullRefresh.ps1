function Invoke-AzOpsGitPullRefresh {

    [CmdletBinding()]
    param ()

    begin {}

    process {
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup
    }

    end {}

}
