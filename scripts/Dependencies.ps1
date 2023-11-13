param (
    [string]
    $Repository = 'PSGallery'
)

# Development Modules
Set-PSRepository -Name $Repository -InstallationPolicy Trusted
$modules = @("Pester", "PSModuleDevelopment", "PSScriptAnalyzer")
Write-Output "Installing development modules"
foreach ($module in $modules) {
    Write-Output "Installing: $module"
    Install-Module $module -Repository $Repository -Force
}
# Runtime Modules
$data = Import-PowerShellDataFile -Path "$PSScriptRoot/../src/AzOps.psd1"
Write-Output "Installing runtime modules"
foreach ($dependency in $data.RequiredModules) {
    $module = Get-Module -Name $dependency.ModuleName -ListAvailable
    if ($module) {
        foreach ($item in $module) {
            Write-Output "Cleanup of: $($item.Name)"
            Uninstall-Module -Name $item.Name -Force
        }
    }
    Write-Output "Installing: $($dependency.ModuleName) $($dependency.RequiredVersion)"
    Install-Module -Name $dependency.ModuleName -RequiredVersion $dependency.RequiredVersion -Repository $Repository
}
# Download and add bicep to PATH
curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
chmod +x ./bicep
sudo mv ./bicep /usr/local/bin/bicep
bicep --help

# List Modules
Get-InstalledModule | Select-Object Name, Version, Repository, InstalledDate | Sort-Object Name | Format-Table
