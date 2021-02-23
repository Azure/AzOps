#Requires -Version 7.0
#Requires -Modules PSFramework

<#
    .SYNOPSIS
        Installs the AzOps Module from GitHub
    .DESCRIPTION
        This script installs the AzOps Module from GitHub.
        It does so by ...
        - downloading the specified branch as zip to $tempPath
        - Unpacking that zip file to a folder in $tempPath
        - Moving that content to a module folder in either program files (default) or the user profile
    .PARAMETER Branch
        The branch to install. Installs master by default.
        Unknown branches will terminate the script in error.
    .PARAMETER UserMode
        The downloaded module will be moved to the user profile, rather than program files.
    .PARAMETER Scope
        By default, the downloaded module will be moved to program files.
        Setting this to 'CurrentUser' installs to the userprofile of the current user.
    .PARAMETER Force
        The install script will overwrite an existing module.
#>

[CmdletBinding()]
param (
    [string]$Branch = "main",

    [switch]$UserMode,

    [ValidateSet('AllUsers', 'CurrentUser')]
    [string]$Scope = "AllUsers",

    [switch]$Force
)


#
# Tasks
# - Push AzOps module to PowerShellGallery
# - Support install from GitHub / PowerShellGallery
#

#region Parameters
$tempPath = [System.IO.Path]::GetTempPath()

$name = "AzOps"
$branch = "main"

$baseUri = "https://github.com/Azure/AzOps"

# Option 1
$uri = "{0}/archive/{1}.zip" -f $baseUri, $branch

# Option 2
$uri = $baseUri + "/archive/" + $branch + ".zip"


$moduleArchiveFile = $tempPath + "\" + $moduleName + ".zip"
$modulePath = $tempPath + "\" + $moduleName

# $doUserMode = $false
# if ($UserMode) {
#     $doUserMode = $true
# }
# if ($install_CurrentUser) {
#     $doUserMode = $true
# }
# if ($Scope -eq 'CurrentUser') {
#     $doUserMode = $true
# }
# if ($install_Branch) {
#     $Branch = $install_Branch
# }
#endregion

try {
    # Preferences - Set
    $ErrorActionPreferenceState = $ErrorActionPreference
    $ErrorActionPreference = "Stop"

    Write-PSFMessage -Level Important -Message "Downloading repository from $moduleUri"
    Invoke-WebRequest -Uri $moduleUri -UseBasicParsing -OutFile $moduleArchiveFile

    Write-PSFMessage -Level Important -Message "Creating temporary project folder $moduleArchivePath"
    New-Item -Path $tempPath -Name $moduleName -ItemType Directory -Force

    Write-PSFMessage -Level Important -Message "Extracting archive to $moduleArchivePath"
    Expand-Archive -Path $moduleArchiveFile -DestinationPath $modulePath

    Write-PSFMessage -Level Important -Message "Determining install path"
    # Install Path

    Write-PSFMessage -Level Important -Message "Checking if module is already installed"
    if ((Test-Path $path) -and (-not $orce)) {
        Write-PSFMessage -Level Important -Message "Module already installed, interrupting installation"
        return
    }

    Write-PSFMessage -Level Important -Message "Creating folder $path"
    #New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop

    Write-PSFMessage -Level Important -Message "Copying files to $path"
    #foreach ($file in (Get-ChildItem -Path $basePath)) {
    #   Move-Item -Path $file.FullName -Destination $path -ErrorAction Stop
    #}

    Write-PSFMessage -Level Important -Message "Cleaning up temporary files"
    #Remove-Item -Path "$($tempPath)\$($moduleName).zip" -Force
    #Remove-Item -Path "$($tempPath)\$($moduleName)" -Force -Recurse

    Write-PSFMessage -Level Important -Message "Installation of the module $moduleName, Branch $branch, Version $moduleVersion completed successfully!"

    # Preferences - Revert
    $ErrorActionPreference = $ErrorActionPreferenceState
}
catch {
    Write-PSFMessage -Level Important -Message "Installation of the module failed!"
    Write-Error -Exception $_.Exception

    Write-PSFMessage -Level Important -Message "Cleaning up temporary files"
    #Remove-Item -Path "$($tempPath)\$($moduleName)" -Force -Recurse
    #Remove-Item -Path "$($tempPath)\$($moduleName).zip" -Force

    throw
}