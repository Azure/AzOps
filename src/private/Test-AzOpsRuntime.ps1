<#
.SYNOPSIS
    The cmdlet verifies that required registry and git settings are enabled to support long paths in Windows execution environments
.DESCRIPTION
    The cmdlet verifies that required registry and git settings are enabled to support long paths in Windows execution environments
    https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#enable-long-paths-in-windows-10-version-1607-and-later
    https://aka.ms/es/quickstart
.EXAMPLE
    C:\PS> Test-AzOpsRuntime
.INPUTS
    None
.OUTPUTS
    None
#>
function Test-AzOpsRuntime {
    [CmdletBinding()]
    param (
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsRuntime" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")

    }
    process {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsRuntime" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        # Only validate in Windows Execution Environments
        if ($PSVersionTable.Platform -eq "Win32NT") {
            Write-AzOpsLog -Level Verbose -Topic "Test-AzOpsRuntime" -Message "Validating Windows environment for LongPath support"
            $RuntimeErrors = @()
            # Validate required registry entry
            $RegistryValue = Get-ItemPropertyValue -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled
            if ($RegistryValue -ne 1) {
                $RuntimeErrors += 'RegistryValueMissing: Registry value (HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled) is not set to 1 to support paths over 256 characters in Windows.'
            }
            # Validate git configuration
            $LongPathGitSetting = Start-AzOpsNativeExecution { git config --system -l } | Select-String 'core.longpaths=true'
            if ([string]::IsNullOrEmpty($LongPathGitSetting)) {
                $RuntimeErrors += 'GitConfigMissing: git config --system core.longpaths is not set to true and is required to support over 256 characters in Git.'
            }
            # Return error messages with instructions if settings are missing
            if ($RuntimeErrors) {
                $RunTimeErrors += 'Follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.'
                Write-AzOpsLog -Level Error -Topic "Test-AzOpsRuntime" -Message ($RuntimeErrors -join "`r")
            }
        }
    }
    end {
        Write-AzOpsLog -Level Debug -Topic "Test-AzOpsRuntime" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}
