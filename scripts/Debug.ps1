#
# Notes
#

# This script has been converted to tabs
# when invoking the AzOpsPush cmdlet the
# Git diff needs to include a tab otherwise
# the expression won't detect the file.

#
# Preferences
#

$ErrorActionPreference = "Stop"
#$VerbosePreference = "Continue"
#$DebugPreference = "Continue"

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

Initialize-AzOpsEnvironment

#
# Internal
#

# & ( Get-Module -Name AzOps ) { $host.EnterNestedPrompt() }
# $module = Get-Module -Name AzOps

#
# Deployment
#

# $tenantId = ""
# $managementId = ""
# $subscriptionId = ""

#$change = "A	root/tenant root group ($tenantId)/test ()/management.jsonc"
Invoke-AzOpsPush -ChangeSet $change