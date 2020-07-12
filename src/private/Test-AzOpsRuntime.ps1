<#
.SYNOPSIS
    The cmdlet verifies that required registry settings are enabled to support long paths in Windows execution environments
.DESCRIPTION
    The cmdlet verifies that required registry settings are enabled to support long paths in Windows execution environments
    https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#enable-long-paths-in-windows-10-version-1607-and-later
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
    # Only check for registry value in Windows Execution Environments
    if ($PSVersionTable.Platform -eq "Win32NT") {
        $RegistryValue = Get-ItemPropertyValue -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled
        if ($RegistryValue -ne 1) {
            Write-AzOpsLog -Level Error -Topic "Test-AzOpsRuntime" -Message  "Registry value (HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem\LongLongPathsEnabled) is not set to 1 to support paths over 256 characters in Windows.
            Change value as per https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file#enable-long-paths-in-windows-10-version-1607-and-later, reboot and try again."
        }

    }
}