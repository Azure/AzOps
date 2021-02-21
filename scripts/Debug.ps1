
$VerbosePreference = "Continue"

Import-Module ./src/AzOps.psd1 -Force

Set-PSFConfig -FullName AzOps.Core.State -Value "/tmp/azops" -Description "-"

#Initialize-AzOpsEnvironment

Remove-Item -Path "/tmp/azops" -Recurse -Force

Initialize-AzOpsRepository -Verbose
