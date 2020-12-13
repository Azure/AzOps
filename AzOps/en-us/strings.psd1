# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Assert-WindowsLongPath.Validating'				      = 'Validating Windows environment for LongPath support'
	'Assert-WindowsLongPath.Failed'					      = 'Windows not sufficiently configured for long paths! Follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.'
	
	'ConvertTo-AzOpsState.Starting'					      = 'Starting conversion to AzOps State object' #
	'ConvertTo-AzOpsState.StateConfig.Error'			  = 'Cannot load {0}, is the json schema valid and does the file exist?' # Get-PSFConfigValue -FullName 'AzOps.General.StateConfig'
	'ConvertTo-AzOpsState.ExcludedProperties'			  = 'Default excluded properties: [{0}]' # ($excludedProperties.Keys -join ', ')
	'ConvertTo-AzOpsState.ObjectType.Resolved'		      = 'Found object type: {0}'
	'ConvertTo-AzOpsState.ObjectType.Resolved.Generic'    = 'Generic object detected, ExportPath expected'
	'ConvertTo-AzOpsState.ResourceError'				  = 'Error processing resource: {0}' # $Resource
	'ConvertTo-AzOpsState.NoExportPath'				      = 'No export path found for {0}. Ensure the original data type remains intact or specify an -ExportPath' # $Resource
	'ConvertTo-AzOpsState.Processing'					  = 'Processing input: {0}' # $Resource
	'ConvertTo-AzOpsState.File.Create'				      = 'AzOpsState file not found. Creating new: {0}' # $resourceData.ObjectFilePath
	'ConvertTo-AzOpsState.Generalized.ExcludedProperties' = 'GeneralizeTemplates used: Excluded properties: [{0}]' # ($excludedProperties.Keys -join ', ')
	'ConvertTo-AzOpsState.Generalized.Exporting'		  = 'Exporting AzOpsState to: {0}' # $originalFilePath
	
	'Initialize-AzOpsEnvironment.AzureContext.No'		  = 'No context available in Az PowerShell. Please use Connect-AzAccount and connect before using the command'
	'Initialize-AzOpsEnvironment.AzureContext.TooMany'    = 'Unsupported number of tenants in context: {0} TenantIDs
TenantIDs: {1}
Please reconnect with Connect-AzAccount using an account/service principal that only have access to one tenant' # $azContextTenants.Count, ($azContextTenants -join ',')
	'Initialize-AzOpsEnvironment.UsingCache'			  = 'Using cached values for AzOpsAzManagementGroup and AzOpsSubscriptions'
	
	'Invoke-NativeCommand.Failed.WithCallstack'		      = 'Execution of {{{0}}} by {1}: line {2} failed with exit code {3}'
	'Invoke-NativeCommand.Failed.NoCallstack'			  = 'Execution of {{{0}}} failed with exit code {1}'
	
	'New-AzOpsScope.Starting'							  = 'Starting creation of new scope object' #
	'New-AzOpsScope.Creating.FromScope'				      = 'Creating new AzOpsScope object using scope [{0}]' # $Scope
	'New-AzOpsScope.Path.NotFound'					      = 'Path not found: {0}' # Path
	'New-AzOpsScope.Path.InvalidRoot'					  = 'Path "{0}" must be a path under "{1}" !' # $Path, $StatePath
	'New-AzOpsScope.Creating.FromFile'				      = 'Creating a new scope from a path' #
	
	'Save-ManagementGroupChildren.Starting'			      = 'Starting execution' #
	'Save-ManagementGroupChildren.Processing'			  = 'Processing Scope: {0}' # $scopeObject.scope
	'Save-ManagementGroupChildren.New.File'			      = 'Creating new state file: {0}' # $statepathFileName
	'Save-ManagementGroupChildren.Moving.Source'		  = 'Found existing state file in directory: {0}' # $exisitingScopePath
	'Save-ManagementGroupChildren.Moving.Destination'	  = 'Moved existing state file to: {0}' # $statepathScopeDirectoryParent
	
	'AzOpsScope.Input.BadData.ManagementGroup'		      = '{0} does not contain .parameters.input.value.Id'
	'AzOpsScope.GetManagementGroupName.Found.Azure'	      = 'Management Group found in Azure: {0}'
	'AzOpsScope.GetManagementGroupName.NotFound'		  = 'Management Group not found in Azure. Using directory name instead: {0}'
	'AzOpsScope.GetSubscription.Found'				      = 'SubscriptionId found in Azure: {0}'
	'AzOpsScope.GetSubscription.NotFound'				  = 'SubscriptionId not found in Azure. Using directory name instead: {0}'
	'AzOpsScope.GetSubscriptionDisplayName.Found'		  = 'Subscription DisplayName found in Azure: {0}'
	'AzOpsScope.GetSubscriptionDisplayName.NotFound'	  = 'Subscription DisplayName not found in Azure. Using directory name instead: {0}'
	'AzOpsScope.GetAzOpsResourcePath.Retrieving'		  = 'Getting Resource path for: {0}'
	'AzOpsScope.GetAzOpsResourcePath.NotFound'		      = 'Unable to determine Resource Scope for: {0}'
}