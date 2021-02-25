Set-PSFFeature -Name PSFramework.Stop-PSFFunction.ShowWarning -Value $true -ModuleName AzOps

if (Get-PSFConfigValue -FullName AzOps.Core.AutoInitialize) {
    Initialize-AzOpsEnvironment
}
