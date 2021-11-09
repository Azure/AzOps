$data = Import-PowerShellDataFile -Path "./src/AzOps.psd1"
$modules = @()
$existingmodule = @()
$newmodule = @()
$data.RequiredModules | ForEach-Object {
    $moduleVersion = $_.RequiredVersion
    $galleryVersion = (Find-Module -Name $_.ModuleName).Version
    if ($moduleVersion -lt $galleryVersion) {
        $newmodule = @{
            "ModuleName"     = $_.ModuleName
            "RequiredVersion" = $galleryVersion
        }
        $modules += $newmodule
    }else {
        $existingmodule = @{
            "ModuleName"     = $_.ModuleName
            "RequiredVersion" = $moduleVersion
        }
        $modules += $existingmodule
    }
}
Update-ModuleManifest -Path "./src/AzOps.psd1" -RequiredModules $modules