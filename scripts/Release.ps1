<#
This script publishes the module to the gallery.
It expects as input an ApiKey authorized to publish the module.

Insert any build steps you may need to take before publishing it here.
#>

param (
    $ApiKey,

    $WorkingDirectory,

    $Repository = 'PSGallery',

    [switch]
    $LocalRepo,

    [switch]
    $SkipPublish,

    [switch]
    $IgnoreDependencies
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory) {
    if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS) {
        $WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
    }
    else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }
#endregion Handle Working Directory Defaults

#region Prepare publish folder
# Remove directory
if (Get-ChildItem -Path $WorkingDirectory -Filter "publish") {
    Write-PSFMessage -Level Important -Message "Removing publishing directory"
    Remove-Item -Path "$($WorkingDirectory)/publish" -Recurse -Force
}
# Create directory
Write-PSFMessage -Level Important -Message "Creating and populating publishing directory"
$publishDir = New-Item -Path $WorkingDirectory -Name publish -ItemType Directory -Force
Copy-Item -Path "$($WorkingDirectory)/src/" -Destination "$($publishDir.FullName)/AzOps/" -Recurse -Force
#endregion Prepare publish folder

#region Gather text data to compile
$text = @()
$processed = @()

# Gather Stuff to run before
foreach ($filePath in (& "$($PSScriptRoot)/../src/internal/scripts/PreImport.ps1")) {
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

    $item = Get-Item $filePath
    if ($item.PSIsContainer) { continue }
    if ($item.FullName -in $processed) { continue }
    $text += [System.IO.File]::ReadAllText($item.FullName)
    $processed += $item.FullName
}

# Gather commands
Get-ChildItem -Path "$($publishDir.FullName)/AzOps/internal/functions/" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $text += [System.IO.File]::ReadAllText($_.FullName)
}
Get-ChildItem -Path "$($publishDir.FullName)/AzOps/functions/" -Recurse -File -Filter "*.ps1" | ForEach-Object {
    $text += [System.IO.File]::ReadAllText($_.FullName)
}

# Gather stuff to run afterwards
foreach ($filePath in (& "$($PSScriptRoot)/../src/internal/scripts/PostImport.ps1")) {
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

    $item = Get-Item $filePath
    if ($item.PSIsContainer) { continue }
    if ($item.FullName -in $processed) { continue }
    $text += [System.IO.File]::ReadAllText($item.FullName)
    $processed += $item.FullName
}
#endregion Gather text data to compile

#region Update the psm1 file
$fileData = Get-Content -Path "$($publishDir.FullName)/AzOps/AzOps.psm1" -Raw
$fileData = $fileData.Replace('"<was not compiled>"', '"<was compiled>"')
$fileData = $fileData.Replace('"<compile code into here>"', ($text -join "`n`n"))
[System.IO.File]::WriteAllText("$($publishDir.FullName)/AzOps/AzOps.psm1", $fileData, [System.Text.Encoding]::UTF8)
#endregion Update the psm1 file

#region Publish
if ($SkipPublish) { return }
if ($LocalRepo) {
    # Dependencies must go first
    # PSFramework
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: PSFramework"
    New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath $publishDir.FullName
    # Az
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: Az.Accounts"
    New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name Az.Accounts -ListAvailable | Select-Object -First 1).ModuleBase -PackagePath $publishDir.FullName
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: Az.Billing"
    New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name Az.Billing -ListAvailable  | Select-Object -First 1).ModuleBase -PackagePath $publishDir.FullName
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: Az.Resources"
    New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name Az.Resources -ListAvailable | Select-Object -First 1).ModuleBase -PackagePath $publishDir.FullName
    # AzOps
    Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: AzOps"
    New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)/AzOps/" -PackagePath $publishDir.FullName

    if ($IgnoreDependencies) {
        Get-ChildItem -Path . -Filter *.nupkg | Where-Object Name -notlike "AzOps*" | Remove-Item -Force
    }
}
else {
    # Publish to Gallery
    Write-PSFMessage -Level Important -Message "Publishing the AzOps module to $($Repository)"
    Publish-Module -Path "$($publishDir.FullName)/AzOps/" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion Publish
