<#
This script updates the module manifest version.
#>

param (
    [Parameter()]
    [ValidateSet("Major", "Minor", "Patch")]
    $Type
)

if ($Type) {
    Write-PSFMessage -Level Important -Message "Updating module version"

    [Version]$currentVersion = (Import-PowerShellDataFile -Path "./src/AzOps.psd1").ModuleVersion
    [Version]$releaseVersion = switch ($Type) {
        "Major" {
            [Version]::new($currentVersion.Major + 1, 0, 0)
        }
        "Minor" {
            $Minor = if ($currentVersion.Minor -le 0) { 1 } else { $currentVersion.Minor + 1 }
            [Version]::new($currentVersion.Major, $Minor, 0)
        }
        "Patch" {
            $Build = if ($currentVersion.Build -le 0) { 1 } else { $currentVersion.Build + 1 }
            [Version]::new($currentVersion.Major, $currentVersion.Minor, $Build)
        }
    }

    Update-ModuleManifest -Path "./src/AzOps.psd1" -ModuleVersion $releaseVersion
}
