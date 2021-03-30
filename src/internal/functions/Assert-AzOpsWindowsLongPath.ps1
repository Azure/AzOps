function Assert-AzOpsWindowsLongPath {

    <#
        .SYNOPSIS
            Asserts that - if on windows - long paths have been enabled.
        .DESCRIPTION
            Asserts that - if on windows - long paths have been enabled.
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Assert-AzOpsWindowsLongPath -Cmdlet $PSCmdlet
            Asserts that - if on windows - long paths have been enabled.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Cmdlet
    )

    process {
        if (-not $IsWindows) {
            return
        }

        Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsWindowsLongPath.Validating'
        $hasRegKey = 1 -eq (Get-ItemPropertyValue -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled)
        $hasGitConfig = (Invoke-AzOpsNativeCommand -ScriptBlock { git config --system -l } -IgnoreExitcode | Select-String 'core.longpaths=true') -as [bool]

        if ($hasGitConfig -and $hasRegKey) {
            return
        }
        if (-not $hasRegKey) {
            Write-PSFMessage -Level Warning -String 'Assert-AzOpsWindowsLongPath.No.Registry'
        }
        if (-not $hasGitConfig) {
            Write-PSFMessage -Level Warning -String 'Assert-AzOpsWindowsLongPath.No.GitCfg'
        }

        $exception = [System.InvalidOperationException]::new('Windows not configured for long paths. Please follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-PSFMessage -Level Warning -String 'Assert-AzOpsWindowsLongPath.Failed' -Tag error
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}