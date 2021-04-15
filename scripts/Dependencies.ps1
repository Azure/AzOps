param (
    [string]
    $Repository = 'PSGallery'
)

# Runtime Modules
$data = Import-PowerShellDataFile -Path "$PSScriptRoot/../src/AzOps.psd1"
foreach ($dependency in $data.RequiredModules) {
    Write-Host "Installing module $($dependency.ModuleName)"
    Install-Module -Name $dependency.ModuleName -RequiredVersion $dependency.RequiredVersion -Repository $Repository -Force
    Import-Module $dependency.ModuleName -Force -PassThru
}

# Development Modules
$modules = @("Pester", "PSModuleDevelopment", "PSScriptAnalyzer")
foreach ($module in $modules) {
    Write-Host "Installing module $module"
    Install-Module $module -Repository $Repository -Force
    Import-Module $module -Force -PassThru
}

# List Modules
Get-InstalledModule | Select-Object Name, Version, Repository, InstalledDate | Sort-Object Name | Format-Table