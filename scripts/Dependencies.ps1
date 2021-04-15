param (
    [string]
    $Repository = 'PSGallery'
)

# Runtime Modules
$data = Import-PowerShellDataFile -Path "$PSScriptRoot/../src/AzOps.psd1"
foreach ($dependency in $data.RequiredModules) {
    Write-Host "Installing module $($dependency.ModuleName) $($dependency.RequiredVersion)"
    Install-Module -Name $dependency.ModuleName -RequiredVersion $dependency.RequiredVersion -Repository $Repository -Force
}

# Development Modules
$modules = @("Pester", "PSModuleDevelopment", "PSScriptAnalyzer")
foreach ($module in $modules) {
    Write-Host "Installing module $module"
    Install-Module $module -Repository $Repository -Force | Out-Null
    Import-Module $module -Force -PassThru
}

# List Modules
Get-Module -ListAvailable

# List Modules
Get-InstalledModule | Select-Object Name, Version, Repository, InstalledDate | Sort-Object Name | Format-Table