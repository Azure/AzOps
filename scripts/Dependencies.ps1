param (
    [string]
    $Repository = 'PSGallery'
)

# Runtime Modules
$data = Import-PowerShellDataFile -Path "$PSScriptRoot/../src/AzOps.psd1"
foreach ($dependency in $data.RequiredModules) {
    Write-Output "Installing module $($dependency.ModuleName) $($dependency.RequiredVersion)"
    Install-Module -Name $dependency.ModuleName -RequiredVersion $dependency.RequiredVersion -Repository $Repository -Force
}

# Development Modules
$modules = @("Pester", "PSModuleDevelopment", "PSScriptAnalyzer")
foreach ($module in $modules) {
    Write-Output "Installing module $module"
    Install-Module $module -Repository $Repository -Force
}

# List Modules
Get-InstalledModule | Select-Object Name, Version, Repository, InstalledDate | Sort-Object Name | Format-Table