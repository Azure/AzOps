#
# Preferences
#

#$DebugPreference = "Continue"
#$VerbosePreference = "Continue"

#
# Config
#

Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 9
#Set-PSFConfig -FullName AzOps.Core.State -Value "/workspaces/azops"
#Set-PSFConfig -FullName AzOps.Import.DoDotSource -Value $true
#Set-PSFConfig -FullName AzOps.Import.IndividualFiles -Value $true

#
# Import
#

Import-Module ./src/AzOps.psd1 -Force

#
# Initialize
#

Initialize-AzOpsRepository -Rebuild

#
# Internal
#

& ( Get-Module -Name AzOps ) { $host.EnterNestedPrompt() }
