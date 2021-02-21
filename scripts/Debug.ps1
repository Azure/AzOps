
Import-Module ./src/AzOps.psd1 -Force -Verbose

Set-PSFConfig -FullName AzOps.General.State -Value "/tmp/azops" -Description "-" -Verbose

Initialize-AzOpsEnvironment -Verbose

#Initialize-AzOpsRepository -SkipPolicy -SkipResourceGroup -Verbose
