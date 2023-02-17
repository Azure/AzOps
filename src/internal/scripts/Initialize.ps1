Set-PSFFeature -Name PSFramework.Stop-PSFFunction.ShowWarning -Value $true -ModuleName AzOps

if ([runspace]::DefaultRunspace.Id -eq 1) {
    Initialize-AzOpsEnvironment
}