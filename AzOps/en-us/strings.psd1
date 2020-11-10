# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Assert-WindowsLongPath.Validating'			       = 'Validating Windows environment for LongPath support'
	'Assert-WindowsLongPath.Failed' = 'Windows not sufficiently configured for long paths! Follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.'
	
	'Initialize-AzOpsEnvironment.AzureContext.No' = 'No context available in Az PowerShell. Please use Connect-AzAccount and connect before using the command'
	'Initialize-AzOpsEnvironment.AzureContext.TooMany' = 'Unsupported number of tenants in context: {0} TenantIDs
TenantIDs: {1}
Please reconnect with Connect-AzAccount using an account/service principal that only have access to one tenant' # $azContextTenants.Count, ($azContextTenants -join ',')
	'Initialize-AzOpsEnvironment.UsingCache'		   = 'Using cached values for AzOpsAzManagementGroup and AzOpsSubscriptions'
	
	'Invoke-NativeCommand.Failed.WithCallstack' = 'Execution of {{{0}}} by {1}: line {2} failed with exit code {3}'
	'Invoke-NativeCommand.Failed.NoCallstack' = 'Execution of {{{0}}} failed with exit code {1}'
}