#
# Notes.
#

#
# Config
#

Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 9
# Set-PSFConfig -FullName AzOps.Core.State -Value "/workspaces/AzOps/root"
# Set-PSFConfig -FullName AzOps.Import.DoDotSource -Value $true
# Set-PSFConfig -FullName AzOps.Import.IndividualFiles -Value $true

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
# Pull
#

# Invoke-AzOpsPull

#
# Push
#

# $tenantId = ""
# $managementId = ""
# $subscriptionId = ""

# $change = "A	root/tenant root group ($tenantId)/azuredeploy.json"
# Invoke-AzOpsPush -ChangeSet $change