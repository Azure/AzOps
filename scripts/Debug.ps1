
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

Set-PSFConfig -FullName AzOps.Core.State -Value "/tmp/azops" -Description "-"
Set-PSFConfig -FullName AzOps.Import.DoDotSource -Value $true
Set-PSFConfig -FullName AzOps.Import.IndividualFiles -Value $true

Import-Module ./src/AzOps.psd1 -Force

#Initialize-AzOpsEnvironment

#Remove-Item -Path "/tmp/azops" -Recurse -Force

#Initialize-AzOpsRepository -Verbose
