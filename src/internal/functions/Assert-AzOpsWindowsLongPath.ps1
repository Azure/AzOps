﻿function Assert-AzOpsWindowsLongPath {

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
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Assert-AzOpsWindowsLongPath.Validating'
        $hasRegKey = 1 -eq (Get-ItemPropertyValue -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled)
        $hasGitConfig = (Invoke-AzOpsNativeCommand -ScriptBlock { git config --system -l } -IgnoreExitcode | Select-String 'core.longpaths=true') -as [bool]
        if (-not $hasGitConfig) {
            # Check global git config if setting not found in system settings
            $hasGitConfig = (Invoke-AzOpsNativeCommand -ScriptBlock { git config --global -l } -IgnoreExitcode | Select-String 'core.longpaths=true') -as [bool]
        }

        if ($hasGitConfig -and $hasRegKey) {
            return
        }
        if (-not $hasRegKey) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsWindowsLongPath.No.Registry'
        }
        if (-not $hasGitConfig) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsWindowsLongPath.No.GitCfg'
        }

        $exception = [System.InvalidOperationException]::new('Windows not configured for long paths. Please follow instructions for "Enabling long paths on Windows" on https://github.com/azure/azops/wiki/troubleshooting#windows.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsWindowsLongPath.Failed'
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}