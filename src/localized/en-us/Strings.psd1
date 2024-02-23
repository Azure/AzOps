# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{

    'Assert-AzOpsInitialization.NoCache'                                            = 'The cache of existing Management Groups and subscriptions has not yet been built! Run Initialize-AzOpsEnvironment to build it.' #
    'Assert-AzOpsInitialization.StateError'                                         = 'The state path offered contains invalid characters and cannot be used in the current filesystem' #

    'Assert-AzOpsWindowsLongPath.Failed'                                            = 'Windows not sufficiently configured for long paths! Follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.' #
    'Assert-AzOpsWindowsLongPath.No.GitCfg'                                         = 'Git has not been configured for long path support' #
    'Assert-AzOpsWindowsLongPath.No.Registry'                                       = 'Windows has not yet been configured for long path support' #
    'Assert-AzOpsWindowsLongPath.Validating'                                        = 'Validating Windows environment for LongPath support' #

    'Assert-AzOpsJqDependency.Validating'                                           = 'Validating if jq is in current path' #
    'Assert-AzOpsJqDependency.Success'                                              = 'Supported version of jq found in current path' #

    'Assert-AzOpsBicepDependency.Validating'                                        = 'Validating if bicep is in current path' #
    'Assert-AzOpsBicepDependency.Success'                                           = 'Bicep found in current path' #
    'Assert-AzOpsBicepDependency.NotFound'                                          = 'Unable to locate bicep binary. Will not be able to deploy bicep templates.' #

    'AzOpsScope.GetAzOpsManagementGroupPath.NotFound'                               = 'Management Group path not found: {0}' # $managementgroupName
    'AzOpsScope.GetAzOpsResourcePath.NotFound'                                      = 'Unable to determine resource Scope for: {0}' # $this.Scope
    'AzOpsScope.GetAzOpsResourcePath.Retrieving'                                    = 'Getting resource path for: {0}' # $this.Scope
    'AzOpsScope.GetManagementGroupName.Found.Azure'                                 = 'Management Group found in Azure: {0}' # $mgName
    'AzOpsScope.GetManagementGroup.NotFound'                                        = 'Management Group does not match any existing in Azure. Assume new resource, using directory name: {0}' # $mgId
    'AzOpsScope.GetManagementGroupName.NotFound'                                    = 'Management Group not found in Azure. Trying with directory name instead: {0}' # $mgId
    'AzOpsScope.GetSubscription.Found'                                              = 'SubscriptionId found in Azure: {0}' # $sub.Id
    'AzOpsScope.GetSubscription.NotFound'                                           = 'SubscriptionId not found in Azure. Using directory name instead: {0}' # $subId
    'AzOpsScope.GetSubscriptionDisplayName.Found'                                   = 'Subscription DisplayName found in Azure: {0}' # $sub.displayName
    'AzOpsScope.GetSubscriptionDisplayName.NotFound'                                = 'Subscription DisplayName not found in Azure. Using directory name instead: {0}' # $subId
    'AzOpsScope.Input.FromFileName.ManagementGroup'                                 = 'Determining management group name from file name {0}' # ($children.FullName -join ', ')
    'AzOpsScope.Input.FromFileName.Subscription'                                    = 'Determining subscription name from file name {0}' # ($children.FullName -join ', ')
    'AzOpsScope.Input.BadData.UnknownType'                                          = 'Invalid File Structure! Cannot find Management Group / Subscription / Resource Group files in {0}!' # $Path
    'AzOpsScope.Input.BadData.TemplateParameterFile'                                = 'Unable to determine type from Template or Template Parameter file: {0}' # filename
    'AzOpsScope.Constructor'                                                        = 'Calling Constructor with value {0}' # scope
    'AzOpsScope.InitializeMemberVariables'                                          = 'Calling InitializeMemberVariablesFromDirectory with value {0}' # scope
    'AzOpsScope.InitializeMemberVariables.Start'                                    = 'Calling InitializeMemberVariables with scope {0}' # Scope
    'AzOpsScope.InitializeMemberVariables.End'                                      = 'Calling InitializeMemberVariables with scope {0}' # Scope
    'AzOpsScope.InitializeMemberVariablesFromDirectory'                             = 'Calling InitializeMemberVariablesFromDirectory with value {0}' # scope
    'AzOpsScope.InitializeMemberVariablesFromDirectory.RootTenant'                  = 'Scope is determined to be tenant root scope: {0}' # scope
    'AzOpsScope.InitializeMemberVariablesFromDirectory.AutoGeneratedFolderPath'     = 'Appended AutoGeneratedTemplateFolderPath {0}'
    'AzOpsScope.InitializeMemberVariablesFromDirectory.ParentSubscription'          = 'Determining parent subscription of resource group {0}' # subscription
    'AzOpsScope.InitializeMemberVariablesFromFile'                                  = 'Calling InitializeMemberVariablesFromFile with value {0}' # scope
    'AzOpsScope.InitializeMemberVariablesFromFile.NotJson'                          = 'Input is not json. using directory to determine scope {0}' # path
    'AzOpsScope.InitializeMemberVariablesFromFile.ResourceId'                       = 'Determine scope based on ResourceId {0}' # ResourceId
    'AzOpsScope.InitializeMemberVariablesFromFile.Id'                               = 'Determine scope based on Id {0}' # Id
    'AzOpsScope.InitializeMemberVariablesFromFile.Type'                             = 'Determine scope based on Type {0}' # Type
    'AzOpsScope.InitializeMemberVariablesFromFile.ResourceType'                     = 'Determine scope based on ResourceType {0}' # ResourceType
    'AzOpsScope.InitializeMemberVariablesFromFile.managementgroups'                 = 'Determine scope based on ResourceType managementgroups {0}' # ResourceType
    'AzOpsScope.InitializeMemberVariablesFromFile.subscriptions'                    = 'Determine scope based on ResourceType subscriptions {0}' # ResourceType
    'AzOpsScope.InitializeMemberVariablesFromFile.resourceGroups'                   = 'Determine scope based on ResourceType resourceGroups {0}' # ResourceType
    'AzOpsScope.InitializeMemberVariablesFromFile.resource'                         = 'Determine scope based on ResourceType {0} and Resource Name {1}' # ResourceType and #Resource Name
    'AzOpsScope.ChildResource.InitializeMemberVariables'                            = 'Determine scope of Child Resource based on ResourceType {0}, Resource Name {1} and Parent ResourceID {2}' # ResourceType, Resource Name, Parent ResourceId

    'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate'                   = 'Converting Bicep template ({0}) to ARM Template JSON ({1})' # $BicepTemplatePath, $transpiledTemplatePath
    'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate.Error'             = 'Failed to convert Bicep template ({0}) to ARM Template JSON' # $BicepTemplatePath
    'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam'                             = 'Determine if Bicep template ({0}) has a bicepparam file at ({1})' # $BicepTemplatePath, $bicepParametersPath
    'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam.NotFound'                    = 'No bicepparam file found for ({0})' # $BicepTemplatePath
    'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam'                      = 'Found bicepparam file ({0}), converting to ARM parameters JSON ({1})' # $bicepParametersPath, $transpiledParametersPath
    'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam.Error'                = 'Failed to convert bicepparam file ({0}) to ARM Template JSON' # $bicepParametersPath

    'ConvertTo-AzOpsState.Exporting'                                                = 'Exporting AzOpsState to {0}' # $resourceData.ObjectFilePath
    'ConvertTo-AzOpsState.Exporting.Default'                                        = 'Exporting input resource to AzOpsState to {0}' # $resourceData.ObjectFilePath
    'ConvertTo-AzOpsState.File.Create'                                              = 'AzOpsState file not found. Creating new: {0}' # $ObjectFilePath
    'ConvertTo-AzOpsState.File.UseExisting'                                         = 'AzOpsState file is found. Using existing file: {0}' # $ObjectFilePath
    'ConvertTo-AzOpsState.NoExportPath'                                             = 'No export path found for {0}. Ensure the original data type remains intact or specify an -ExportPath' # $Resource
    'ConvertTo-AzOpsState.Processing'                                               = 'Processing input: {0}' # $Resource
    'ConvertTo-AzOpsState.Starting'                                                 = 'Starting conversion to AzOps State object' #
    'ConvertTo-AzOpsState.GenerateTemplateParameter'                                = 'Generating template parameter: {0}' # $generateTemplateParameter
    'ConvertTo-AzOpsState.GenerateTemplate'                                         = 'Generating template: {0}' # $generateTemplateParameter
    'ConvertTo-AzOpsState.GenerateTemplate.ProviderNamespace'                       = 'Provider namespace: {0}' # $providerNamespace
    'ConvertTo-AzOpsState.GenerateTemplate.ResourceTypeName'                        = 'Resource type: {0}' # $resourceTypeName
    'ConvertTo-AzOpsState.GenerateTemplate.ResourceApiTypeName'                     = 'Resource api type: {0}' # $resourceApiTypeName
    'ConvertTo-AzOpsState.GenerateTemplate.ApiVersion'                              = 'Determined api version: {1} for resource type name: {0}' # $resourceType, $apiVersions
    'ConvertTo-AzOpsState.GenerateTemplate.NoApiVersion'                            = 'Unable to determine api version from resource type name: {0}' # $resourceTypeName
    'ConvertTo-AzOpsState.GenerateTemplate.ChildResource'                           = 'Appending child resource name: {0}' # $resourceName
    'ConvertTo-AzOpsState.ObjectType.Resolved.Generic'                              = 'Unable to determine object type: {0}' # $($_.GetType())
    'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject'                             = 'Determined object type based on PowerShell class {0}' # $($_.GetType())
    'ConvertTo-AzOpsState.ObjectType.Resolved.ResourceType'                         = 'Determined object type based on resourceType {0}' # $Resource.ResourceType
    'ConvertTo-AzOpsState.Jq.Remove'                                                = 'Using Jq Remove Template at path {0}'# jqRemoveTemplate
    'ConvertTo-AzOpsState.Jq.Template'                                              = 'Using Jq Json Template at path {0}'# jqRemoveTemplate
    'ConvertTo-AzOpsState.Subscription.ChildResource.Jq.Template'                   = 'Using Jq Json Template at path {0}' # $jqJsonTemplate
    'ConvertTo-AzOpsState.Subscription.ChildResource.Exporting'                     = 'Exporting AzOpsState to {0}' # $resourceData.ObjectFilePath'

    'Get-AzOpsCurrentPrincipal.AccountType'                                         = 'Current AccountType is {0}' #$AzContext.Account.Type
    'Get-AzOpsCurrentPrincipal.PrincipalId'                                         = 'Current PrincipalId is {0}' #$principalObject.id

    'Get-AzOpsManagementGroup.Failed'                                               = 'Get-AzManagementGroup -GroupId {0} failed' #$ManagementGroup

    'Get-AzOpsPolicyAssignment.ManagementGroup'                                     = 'Retrieving Policy Assignment for Management Group {0} ({1})' # $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
    'Get-AzOpsPolicyAssignment.ResourceGroup'                                       = 'Retrieving Policy Assignment for Resource Group in {0} Subscription objects' # $Subscription.count
    'Get-AzOpsPolicyAssignment.Subscription'                                        = 'Retrieving Policy Assignment for {0} Subscription objects' # $Subscription.count

    'Get-AzOpsPolicyDefinition.ManagementGroup'                                     = 'Retrieving custom policy definitions for Management Group [{0}] ({1})' # $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
    'Get-AzOpsPolicyDefinition.Subscription'                                        = 'Retrieving custom policy definitions for {0} Subscription objects' # $Subscription.count

    'Get-AzOpsPolicyExemption.ManagementGroup'                                      = 'Retrieving Policy Exemption for Management Group {0} ({1})' # $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
    'Get-AzOpsPolicyExemption.ResourceGroup'                                        = 'Retrieving Policy Exemption for Resource Group {0}' # $ScopeObject.ResourceGroup
    'Get-AzOpsPolicyExemption.Subscription'                                         = 'Retrieving Policy Exemption for Subscription {0} ({1})' # $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
    'Get-AzOpsPolicyExemption.Failed'                                               = 'Retrieving Policy Exemption failed at {0}' # $ScopeObject.Scope

    'Get-AzOpsResourceLock.ResourceGroup'                                           = 'Retrieving Resource Locks for Resource Group {0}' # $ScopeObject.ResourceGroup
    'Get-AzOpsResourceLock.Failed'                                                  = 'Failed retrieving Resource Locks {0}' # $_
    'Get-AzOpsResourceLock.Subscription'                                            = 'Retrieving Resource Locks for Subscription {0} ({1})' # $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription

    'Get-AzOpsPolicySetDefinition.ManagementGroup'                                  = 'Retrieving PolicySet Definition for ManagementGroup {0} ({1})' # $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
    'Get-AzOpsPolicySetDefinition.Subscription'                                     = 'Retrieving PolicySet Definition for {0} Subscription objects' # $Subscription.count

    'Get-AzOpsResourceDefinition.ChildResource.Warning'                             = 'Failed to export childResources in [{0}]. Warning: [{1}]' # $resourceGroup.ResourceGroupName, $_
    'Get-AzOpsResourceDefinition.Finished'                                          = 'Finished processing scope [{0}]' # $scopeObject.Scope
    'Get-AzOpsResourceDefinition.ManagementGroup.Processing'                        = 'Processing Management Group [{0}] ({1})' # $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
    'Get-AzOpsResourceDefinition.Processing'                                        = 'Processing resources at [{0}]' # $Scope
    'Get-AzOpsResourceDefinition.Processing.Detail'                                 = 'Processing detail: {0} for [{1}]' # 'Policy Definitions', $scopeObject.Scope
    'Get-AzOpsResourceDefinition.Processing.NotFound'                               = 'Scope [{0}] not found in Azure or is excluded' # $Scope
    'Get-AzOpsResourceDefinition.NoResourceGroup'                                   = 'No non-managed Resource Group found in [{0}])' # $scopeObject.Name
    'Get-AzOpsResourceDefinition.Subscription.Processing'                           = 'Processing Subscription [{0}] ({1})' # $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
    'Get-AzOpsResourceDefinition.Subscription.NotFound'                             = 'No Subscription found to process Resource Groups in' #
    'Get-AzOpsResourceDefinition.Processing.Resource'                               = 'Processing resource [{0}] in resource Group [{1}]' # $resource.Name, $resourceGroup.ResourceGroupName
    'Get-AzOpsResourceDefinition.Processing.Resource.Discovery'                     = 'Searching for resources in [{0}]' # $scopeObject.Name
    'Get-AzOpsResourceDefinition.Processing.Resource.Discovery.NotFound'            = 'No resources found in [{0}]' # $scopeObject.Name
    'Get-AzOpsResourceDefinition.Processing.Resource.Warning'                       = 'Failed to get resources in {0}]. Consider excluding the resource causing the failure with [Core.SkipResourceType] setting' # $scopeObject.Name
    'Get-AzOpsResourceDefinition.SkippingResourceGroup'                             = 'SkipResourceGroup switch used, skipping resource Group discovery' #
    'Get-AzOpsResourceDefinition.SkippingResources'                                 = 'SkipResource switch used, skipping resource discovery.' #
    'Get-AzOpsResourceDefinition.Processing.ChildResource'                          = 'Processing resource [{0}] in resource Group [{1}]' # $resource.Name, $resourceGroup.ResourceGroupName
    'Get-AzOpsResourceDefinition.SkippingChildResources'                            = 'SkipChildResource switch used, skipping child resource discovery' #

    'Get-AzOpsRoleAssignment.Assignment'                                            = 'Found assignment {0} for role {1}' # $roleAssignment.id, $roleAssignment.properties.roleDefinitionId
    'Get-AzOpsRoleAssignment.Processing.Failed'                                     = 'Failed retrieving roleAssignment {0}' # $_
    'Get-AzOpsRoleAssignment.Processing'                                            = 'Retrieving Role Assignments at scope {0}' # $ScopeObject

    'Get-AzOpsRoleDefinition.Processing'                                            = 'Processing scope {0}' # $ScopeObject
    'Get-AzOpsRoleDefinition.Processing.Failed'                                     = 'Failed retrieving roleDefinition {0}' # $_
    'Get-AzOpsRoleDefinition.Definition'                                            = 'Processing object {0}' # $roleDefinition.id

    'Get-AzOpsRoleEligibilityScheduleRequest.Processing'                            = 'Retrieving Privileged Identity Management RoleEligibilitySchedule at [{0}]' # $ScopeObject.Scope
    'Get-AzOpsRoleEligibilityScheduleRequest.Assignment'                            = 'Found Privileged Identity Management RoleEligibilityScheduleRequest assignment [{0}]' # $roleEligibilitySchedule.Name

    'Get-AzOpsSubscription.Excluded.Offers'                                         = 'Excluded subscription offers: {0}' # ($ExcludedOffers -join ',')
    'Get-AzOpsSubscription.Excluded.States'                                         = 'Excluded subscription states: {0}' # ($ExcludedStates -join ',')
    'Get-AzOpsSubscription.NoSubscriptions'                                         = 'No relevant subscriptions found!' #
    'Get-AzOpsSubscription.Subscriptions.Excluded'                                  = 'Number of subscriptions excluded: {0}' # ($allSubscriptionsResults.Count - $includedSubscriptions.Count)
    'Get-AzOpsSubscription.Subscriptions.Found'                                     = 'Number of subscriptions found: {0}' # $allSubscriptionsResults.Count
    'Get-AzOpsSubscription.Subscriptions.Included'                                  = 'Number of subscriptions included: {0}' # $includedSubscriptions.Count
    'Get-AzOpsSubscription.Subscriptions.PastDue'                                   = 'Number of included subscriptions in the state "PastDue": {0}' # ($includedSubscriptions | Where-Object State -EQ PastDue).Count

    'Get-AzOpsTemplateFile.Processing'                                              = 'Identifying template for file: {0}' # $File
    'Get-AzOpsTemplateFile.Processing.Fallback'                                     = 'Identifying template for file: {0} with fallback: {1}' # $File, $Fallback
    'Get-AzOpsTemplateFile.Processing.Path'                                         = 'Identifying template for file: {0} at {1}' # $File, $JqTemplatePath/$CustomJqTemplatePath
    'Get-AzOpsTemplateFile.Processing.Found'                                        = 'Identified template: {0}' # $return
    'Get-AzOpsTemplateFile.Processing.NotFound'                                     = 'No template identified for: {0}' # $return

    'Initialize-AzOpsEnvironment.AzureContext.No'                                   = 'No context available in Az PowerShell. Please use Connect-AzAccount and connect before using the command' #
    'Initialize-AzOpsEnvironment.AzureContext.TooMany'                              = 'Unsupported number of tenants in context: {0} TenantIDs TenantIDs: {1} Please reconnect with Connect-AzAccount using an account/service principal that only have access to one tenant' # $azContextTenants.Count, ($azContextTenants -join ',')
    'Initialize-AzOpsEnvironment.Initializing'                                      = 'Starting AzOps environment initialization' #
    'Initialize-AzOpsEnvironment.CurrentPrincipal.Fail'                             = 'Identifying current principal failed with: {0}' # $_
    'Initialize-AzOpsEnvironment.CurrentPrincipal.RoleAssignmentFail'               = 'Identifying current principal root scope "/" roleAssignment failed with: {0}' # $_
    'Initialize-AzOpsEnvironment.ManagementGroup.Expanding'                         = 'Expanding management groups under {0}' # $mgmtGroup.Name
    'Initialize-AzOpsEnvironment.ManagementGroup.NoRootPermissions'                 = 'Principal {0} does not have permissions under / in tenant, enabling partial discovery' # $currentAzContext.Account.Id
    'Initialize-AzOpsEnvironment.ManagementGroup.PartialDiscovery'                  = 'Executing partial discovery' #
    'Initialize-AzOpsEnvironment.ManagementGroup.Resolution'                        = 'Resolving {0} management groups' # $managementGroups.Count
    'Initialize-AzOpsEnvironment.ManagementGroup.NoManagementGroupAccess'           = 'No management group access, discovery will happen from subscription scope(s)'
    'Initialize-AzOpsEnvironment.Processing'                                        = 'Processing AzOps environment' #
    'Initialize-AzOpsEnvironment.Processing.Completed'                              = 'AzOps environment initialization concluded' #
    'Initialize-AzOpsEnvironment.ThrottleLimit.Adjustment'                          = 'Adjusting AzOps.Core.ThrottleLimit from {0} to 5 due to available CPU Cores ({1}) to ensure reliable and performant pipeline execution. For further details, refer to: https://github.com/azure/azops/wiki/performance-considerations' # $throttleLimit, $cpuCores
    'Initialize-AzOpsEnvironment.MultipleTemplateParameterFileSuffix.Adjustment'    = 'Adjusting AzOps.Core.MultipleTemplateParameterFileSuffix from ({0}) to ({1}) to ensure reliable file matching. To avoid this warning update your MultipleTemplateParameterFileSuffix setting to startwith a [.]' # AzOps.Core.MultipleTemplateParameterFileSuffix, $updateMultipleTemplateParameterFileSuffix
    'Initialize-AzOpsEnvironment.SkipCustomJqTemplate.True'                         = 'AzOps.Core.SkipCustomJqTemplate is true, using module defaults' #
    'Initialize-AzOpsEnvironment.CustomJqTemplatePath'                              = 'AzOps.Core.CustomJqTemplatePath {0}' # $customJqTemplatePath
    'Initialize-AzOpsEnvironment.CustomJqTemplatePath.PathNotFound'                 = 'The path specified in AzOps.Core.CustomJqTemplatePath {0} was not found, reverting to module defaults' # $customJqTemplatePath
    'Initialize-AzOpsEnvironment.UsingCache'                                        = 'Using cached values for AzOpsAzManagementGroup and AzOpsSubscriptions' #

    'Invoke-AzOpsPull.Deleting.State'                                               = 'Removing state in {0}' # $StatePath
    'Invoke-AzOpsPull.Duration'                                                     = 'AzOps repository setup completed in {0}' # $stopWatch.Elapsed
    'Invoke-AzOpsPull.Initialization.Completed'                                     = 'Completed preparations for the AzOps repository setup' #
    'Invoke-AzOpsPull.Migration.Required'                                           = 'Migration from previous repository state IS required' #
    'Invoke-AzOpsPull.Building.State'                                               = 'Building AzOpsState structure recursively at {0}' # $StatePath
    'Invoke-AzOpsPull.Rebuilding.State'                                             = 'Rebuilding state in {0}' # $StatePath
    'Invoke-AzOpsPull.Tenant'                                                       = 'Connected to tenant {0}' # $tenantId
    'Invoke-AzOpsPull.TemplateParameterFileSuffix'                                  = 'Template parameter file suffix {0}' # $TemplateParameterFileSuffix
    'Invoke-AzOpsPull.Validating.AADP2'                                             = 'Asserting fundamental Azure AD P2 licensing' #
    'Invoke-AzOpsPull.Validating.AADP2.Success'                                     = 'Azure AD P2 licensing validated' #
    'Invoke-AzOpsPull.Validating.AADP2.Failed'                                      = 'Azure AD P2 licensing not found' #
    'Invoke-AzOpsPull.Validating.UserRole'                                          = 'Asserting fundamental Azure access' #
    'Invoke-AzOpsPull.Validating.UserRole.Failed'                                   = 'Insufficient access to Azure AD. Privileged Identity Management information will not be pulled' #
    'Invoke-AzOpsPull.Validating.UserRole.Success'                                  = 'Azure access validated' #
    'Invoke-AzOpsPull.Validating.ResourceGroupDiscovery.Failed'                     = 'SkipResource set to false or SkipChildResource set to false requires SkipResourceGroup to be set to false. Change value for SkipResourceGroup and retry operation. {0} https://github.com/azure/azops/wiki/settings' #
    'Invoke-AzOpsPull.SkipResourceType.Failed'                                      = 'SkipResourceType setting conflict found in IncludeResourceType, ignoring {0} from IncludeResourceType. To avoid this remove {0} from IncludeResourceType or SkipResourceType' # $resourceTypeDiff.InputObject

    'Invoke-AzOpsRestMethod.Processing'                                             = 'Invoke-AzRestMethod processing path: [{0}]' # $Path
    'Invoke-AzOpsRestMethod.Processing.Error'                                       = 'Invoke-AzRestMethod received [{0}] while processing: [{1}]' # $_, $Path
    'Invoke-AzOpsRestMethod.Processing.RateLimit'                                   = 'Invoke-AzRestMethod is throttled while processing: [{0}], going to sleep for {1} seconds' # $Path, $_.value

    'Invoke-AzOpsPush.Change.AddModify'                                             = 'Adding or modifying:' #
    'Invoke-AzOpsPush.Change.AddModify.File'                                        = '  {0}' # $item
    'Invoke-AzOpsPush.Change.Delete'                                                = 'Deleting:' #
    'Invoke-AzOpsPush.Change.Delete.File'                                           = '  {0}' # $fileName
    'Invoke-AzOpsPush.Change.Delete.TempFile'                                       = 'Creating temporary file dir for deletion processing: {0}' # $fileName
    'Invoke-AzOpsPush.Change.Delete.NextTempFile'                                   = 'Exiting while loop, file detected in $DeleteSetContents for deletion processing based on this content line: [{0}]' # $currentLine
    'Invoke-AzOpsPush.Change.Delete.SetTempFileContent'                             = 'Set temporary file content: [{1}], in [{0}]' # $fileName, $jsonValue
    'Invoke-AzOpsPush.Deletion.Failed'                                              = 'Deletion of resources {0}, has failed using templates: {1}, {2}, this could be due to delayed deletion acceptance from Azure, please investigate and take action.' # $fail.FullyQualifiedResourceId, $fail.TemplateFilePath, $fail.TemplateParameterFilePath
    'Invoke-AzOpsPush.Deletion.Retry'                                               = 'Deletion of {0} resources unsuccessful, initiate final retry combination.' # $retry.Count
    'Invoke-AzOpsPush.Deploy.ProviderFeature'                                       = 'Invoking new state deployment - *.providerfeatures.json for a file {0}' # $addition
    'Invoke-AzOpsPush.Deploy.ResourceProvider'                                      = 'Invoking new state deployment - *.resourceproviders.json for a file {0}' # $addition
    'Invoke-AzOpsPush.Deploy.Subscription'                                          = 'Invoking new state deployment - *.subscription.json for a file {0}' # $addition
    'Invoke-AzOpsPush.Deployment.Required'                                          = 'Deployment required' #
    'Invoke-AzOpsPush.Deployment.Parallel'                                          = 'Running parallel deployments of {1} items with matching TemplateFilePath: {0}' # $deployment, $targets
    'Invoke-AzOpsPush.Deployment.Serial'                                            = 'Running {0} serial deployments' # $uniqueDeployment
    'Invoke-AzOpsPush.Deployment.Skip'                                              = 'Skipping deployment of template: {0} with parameter: {1}, its already been deployed' # $deployment.TemplateFilePath, $deployment.TemplateParameterFilePath
    'Invoke-AzOpsPush.Deployment.ParallelCondition'                                 = 'Parallel deployment condition true' #
    'Invoke-AzOpsPush.Deployment.ParallelGroup'                                     = 'Identified multiple deployments with matching TemplateFilePath' # $groups
    'Invoke-AzOpsPush.Dependency.Missing'                                           = 'Missing resource dependency for successfull deletion. Error exiting runtime.'
    'Invoke-AzOpsPush.DeploymentList.NotFound'                                      = 'Expecting deploymentList object, it was not found. Error exiting runtime.'
    'Invoke-AzOpsPush.Duration'                                                     = 'AzOps Push completed in {0}' # $stopWatch.Elapsed
    'Invoke-AzOpsPush.Resolve.FoundTemplate'                                        = 'Found template {1} for parameters {0}' # $FilePath, $templatePath
    'Invoke-AzOpsPush.Resolve.FoundBicepTemplate'                                   = 'Found Bicep template {1} for parameters {0}' # $FilePath, $bicepTemplatePath
    'Invoke-AzOpsPush.Resolve.FromMainTemplate'                                     = 'Determining template from main template file: {0}' # $mainTemplateItem.FullName
    'Invoke-AzOpsPush.Resolve.MainTemplate.NotSupported'                            = 'effectiveResourceType: {0} AzOpsMainTemplate does NOT supports resource type {0} in {1}. Deployment will be ignored' # $effectiveResourceType, $AzOpsMainTemplate.FullName
    'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile'                        = 'Found AllowMultipleTemplateParameterFile {0}' # $FilePath
    'Invoke-AzOpsPush.Resolve.MainTemplate.Supported'                               = 'effectiveResourceType: {0} - AzOpsMainTemplate supports resource type {0} in {1}' # $effectiveResourceType, $AzOpsMainTemplate.FullName
    'Invoke-AzOpsPush.Resolve.NoJson'                                               = 'The specified file is not a json or bicep file! Skipping {0}' # $fileItem.FullName
    'Invoke-AzOpsPush.Resolve.NotFoundTemplate'                                     = 'Did NOT find template {1} for parameters {0}' # $FilePath, $templatePath
    'Invoke-AzOpsPush.Resolve.ParameterFound'                                       = 'Found parameter file for template {0} : {1}' # $FilePath, $parameterPath
    'Invoke-AzOpsPush.Resolve.ParameterNotFound'                                    = 'No parameter file found for template {0} : {1}' # $FilePath, $parameterPath
    'Invoke-AzOpsPush.Resolve.NotFoundParamFileDefaultValue'                        = 'Template {0} with parameter: {1} missing defaultValue and no parameter file found, skip deployment' # $FilePath, $missingString
    'Invoke-AzOpsPush.Scope.Failed'                                                 = 'Failed to read {0} as part of {1}' # $addition, $StatePath

    'Invoke-AzOpsNativeCommand'                                                     = 'Execution of ScriptBlock: {{{0}}} returned: {{{1}}}' # $ScriptBlock, $_
    'Invoke-AzOpsNativeCommand.Failed.NoCallstack'                                  = 'Execution of {{{0}}} failed with exit code {1}' # $ScriptBlock, $LASTEXITCODE
    'Invoke-AzOpsNativeCommand.Failed.WithCallstack'                                = 'Execution of {{{0}}} by {1}: line {2} failed with exit code {3}' # $ScriptBlock, $caller[1].ScriptName, $caller[1].ScriptLineNumber, $LASTEXITCODE

    'Invoke-AzOpsScriptBlock.Failed.GivingUp'                                       = 'Tried {0} unsuccessfully {1} out of {2} times, giving up.' # $ScriptBlock, $count, $RetryCount
    'Invoke-AzOpsScriptBlock.Failed.WillRetry'                                      = 'Tried {0} unsuccessfully {1} out of {2} times, keeping up the fight!' # $ScriptBlock, $count, $RetryCount

    'New-AzOpsScope.Creating.FromFile'                                              = 'Creating new scope from path {0}' # $Path
    'New-AzOpsScope.Creating.FromScope'                                             = 'Creating new AzOpsScope object using scope [{0}]' # $Scope
    'New-AzOpsScope.Creating.FromParentScope'                                       = 'Creating new AzOpsScope statepath using parent scope [{0}] with child resource details' # $Scope
    'New-AzOpsScope.Path.InvalidRoot'                                               = 'Path "{0}" must be a path under "{1}" !' # $Path, $StatePath
    'New-AzOpsScope.Path.NotFound'                                                  = 'Path not found: {0}' # $Path
    'New-AzOpsScope.Starting'                                                       = 'Starting creation of new scope object' #

    'New-AzOpsDeployment.ManagementGroup.Processing'                                = 'Attempting [Management Group] deployment in [{0}] for {1}' # $defaultDeploymentRegion, $scopeObject
    'New-AzOpsDeployment.Processing'                                                = 'Processing deployment {0} for template {1} with parameter "{2}" in mode {3}' # $DeploymentName, $TemplateFilePath, $TemplateParameterFilePath, $Mode
    'New-AzOpsDeployment.ResourceGroup.Processing'                                  = 'Attempting [resource Group] deployment for {0}' # $scopeObject
    'New-AzOpsDeployment.Root.Processing'                                           = 'Attempting [Tenant Scope] deployment in [{0}] for {1}' # $defaultDeploymentRegion, $scopeObject
    'New-AzOpsDeployment.Scope.Empty'                                               = 'Unable to determine the scope of template {0} and parameters {1}' # $TemplateFilePath, $TemplateParameterFilePath
    'New-AzOpsDeployment.Scope.Failed'                                              = 'Failed to resolve the scope for template {0} and parameters {1}' # $TemplateFilePath, $TemplateParameterFilePath
    'New-AzOpsDeployment.Scope.Unidentified'                                        = 'Unable to determine to scope type for this Az deployment : {0}' # $scopeObject
    'New-AzOpsDeployment.Subscription.Processing'                                   = 'Attempting [Subscription] deployment in [{0}] for {1}' # $defaultDeploymentRegion, $scopeObject
    'New-AzOpsDeployment.TemplateParameterError'                                    = 'Error due to empty parameter - will not attempt to deploy template. Error can be ignored for bicep modules.' # $
    'New-AzOpsDeployment.TemplateError'                                             = 'Error validating template: {0}' # $TemplateFilePath
    'New-AzOpsDeployment.WhatIfWarning'                                             = 'Error returned from WhatIf API: {0}' # $resultsError
    'New-AzOpsDeployment.WhatIfResults'                                             = 'WhatIf Results: {0}' # $TemplateFilePath
    'New-AzOpsDeployment.WhatIfFile'                                                = 'Creating WhatIf Results file'
    'New-AzOpsDeployment.SkipDueToWhatIf'                                           = 'Skipping deployment due to WhatIf' #
    'New-AzOpsDeployment.Parent.NotFound'                                           = 'Failed to find parent scope for template {0}' # $addition
    'New-AzOpsDeployment.Directory.NotFound'                                        = 'Directory name {0} does not match expected {1}' # (Get-Item -Path $pathDir).Name, "$($resource.properties.displayName) ($($resource.name))"

    'New-AzOpsStateDeployment.EnrollmentAccount.First'                              = 'No enrollment account defined, using the first account found: {0}' # @($enrollmentAccounts)[0].PrincipalName
    'New-AzOpsStateDeployment.EnrollmentAccount.Selected'                           = 'Using the defined enrollment account {0}' # $cfgEnrollmentAccount
    'New-AzOpsStateDeployment.InvalidScope'                                         = 'Unable to determine scope type for {0}, skipping' # $FileName
    'New-AzOpsStateDeployment.NoEnrollmentAccount'                                  = 'No Azure Enrollment account found for current Azure context' #
    'New-AzOpsStateDeployment.NoEnrollmentAccount.Solution'                         = 'Create new Azure role assignment for service principal used for pipeline: New-AzRoleAssignment -ObjectId <application-Id> -RoleDefinitionName Owner -Scope /providers/Microsoft.Billing/enrollmentAccounts/<object-Id>' #
    'New-AzOpsStateDeployment.Processing'                                           = 'Processing new state deployment for {0}' # $FileName
    'New-AzOpsStateDeployment.Subscription'                                         = 'Upserting subscriptions for {0}' # $FileName
    'New-AzOpsStateDeployment.Subscription.AssignManagementGroup'                   = 'Assigning subscription {0} to management group {1}' # $subscription.Name, $scopeObject.ManagementGroupDisplayName
    'New-AzOpsStateDeployment.Subscription.Creating'                                = 'Creating new subscription: {0}' # $scopeObject.Name
    'New-AzOpsStateDeployment.Subscription.Exists'                                  = 'Existing subscription found: {0} ({1})' # $subscription.Name, $subscription.Id
    'New-AzOpsStateDeployment.Subscription.New'                                     = 'Creating new subscription for {0}' # $FileName

    'Register-AzOpsProviderFeature.Context.Failed'                                  = 'Failed to switch content to subscription {0}' # $ScopeObject.SubscriptionDisplayName
    'Register-AzOpsProviderFeature.Context.Switching'                               = 'Switching Subscription context from {0}/{1} to {2}/{3}' # $currentContext.Subscription.Name, $CurrentAzContext.Subscription.Id, $ScopeObject.Subscription, $ScopeObject.Name
    'Register-AzOpsProviderFeature.Processing'                                      = 'Processing provider feature {0} from {1}' # $ScopeObject, $FileName
    'Register-AzOpsProviderFeature.Provider.Feature'                                = 'Registering Feature {0} in Provider {1} namespace' # $ProviderFeature.FeatureName, $ProviderFeature.ProviderName

    'Register-AzOpsResourceProvider.Context.Failed'                                 = 'Failed to switch content to subscription {0}' # $ScopeObject.SubscriptionDisplayName
    'Register-AzOpsResourceProvider.Context.Switching'                              = 'Switching Subscription context from {0}/{1} to {2}/{3}' # $currentContext.Subscription.Name, $CurrentAzContext.Subscription.Id, $ScopeObject.Subscription, $ScopeObject.Name
    'Register-AzOpsResourceProvider.Processing'                                     = 'Processing resource provider {0} from {1}' # $ScopeObject, $FileName
    'Register-AzOpsResourceProvider.Provider.Register'                              = 'Registering provider {0}' # $resourceprovider.ProviderNamespace

    'Remove-AzOpsDeployment.Processing'                                             = 'Processing removal {0} for template {1}' # $removeJobName, $TemplateFilePath
    'Remove-AzOpsDeployment.Metadata.AzOps'                                         = 'Resource deletion detected with AzOps generated template file {0}' # $TemplateFilePath
    'Remove-AzOpsDeployment.Metadata.Custom'                                        = 'Resource deletion detected with custom template file: {0}' #$TemplateFilePath
    'Remove-AzOpsDeployment.Metadata.Failed'                                        = 'Detected custom template: {0}, and Core.CustomTemplateResourceDeletion is not set to true' #$TemplateFilePath
    'Remove-AzOpsDeployment.Scope.Failed'                                           = 'Failed to resolve the scope for template {0}' # $TemplateFilePath
    'Remove-AzOpsDeployment.Scope.Empty'                                            = 'Unable to determine the scope of template {0}' # $TemplateFilePath
    'Remove-AzOpsDeployment.SkipDueToWhatIf'                                        = 'Skipping removal of resource due to WhatIf' #
    'Remove-AzOpsDeployment.ResourceDependencyNested'                               = 'resource dependency {0} for complete deletion of {1} is outside of supported AzOps scope. Please remove this dependency in Azure without AzOps.'# $roleAssignmentId, $policyAssignment.ResourceId
    'Remove-AzOpsDeployment.ResourceDependencyNotFound'                             = 'Missing resource dependency {0} for successfull deletion of {1}. Please add missing resource and retry.'# $resource.ResourceId, $scopeObject.Scope
    'Remove-AzOpsDeployment.Resource.RetryCount'                                    = 'Retry deletion of {0} resources in different order'# $retry.Count
    'Remove-AzOpsDeployment.ResourceNotFound'                                       = 'Unable to find resource of type {0} with id {1}.'# $scopeObject.resource, $scopeObject.scope, $resultsError
    'Remove-AzOpsDeployment.SkipUnsupportedResource'                                = 'Deletion of AzOps generated file resources is only supported for locks, policyAssignments, policyDefinitions, policyExemptions, policySetDefinitions and roleAssignments. Will NOT proceed with deletion of resource in file {0}'# $TemplateFilePath

    'Remove-AzResourceRaw.Resource.Failed'                                          = 'Unable to delete resource of type {0} with id {1}'# $scopeObject.scope, $FullyQualifiedResourceId

    'Remove-AzResourceRawRecursive.Processing'                                      = 'Recursive retry processing to delete resource of type {0} with id {1}'# $item.ScopeObject.resource, $item.FullyQualifiedResourceId

    'Remove-AzOpsInvalidCharacter.Completed'                                        = 'Valid string: {0}'# $String
    'Remove-AzOpsInvalidCharacter.Invalid'                                          = 'Invalid character detected in string: {0}, further processing initiated'# $String
    'Remove-AzOpsInvalidCharacter.Removal'                                          = 'Removed invalid character: {0} from string: {1}'# $character, $String

    'Save-AzOpsManagementGroupChild.Creating.Scope'                                 = 'Creating scope object' #
    'Save-AzOpsManagementGroupChild.Data.Directory'                                 = 'Resolved state path directory: {0}' # $statepathDirectory
    'Save-AzOpsManagementGroupChild.Data.FileName'                                  = 'Resolved state path filename: {0}' # $statepathFileName
    'Save-AzOpsManagementGroupChild.Data.ScopeDirectory'                            = 'Resolved state path scope directory: {0}' # $statepathScopeDirectory
    'Save-AzOpsManagementGroupChild.Data.ScopeDirectoryParent'                      = 'Resolved state path scope directory parent: {0}' # $statepathScopeDirectoryParent
    'Save-AzOpsManagementGroupChild.Data.StatePath'                                 = 'Resolved state path: {0}' # $scopeStatepath
    'Save-AzOpsManagementGroupChild.Moving.Destination'                             = 'Moved existing state file to: {0}' # $statepathScopeDirectoryParent
    'Save-AzOpsManagementGroupChild.Moving.Source'                                  = 'Found existing state file in directory: {0}' # $exisitingScopePath
    'Save-AzOpsManagementGroupChild.Processing'                                     = 'Processing Scope: {0}' # $scopeObject.Scope
    'Save-AzOpsManagementGroupChild.Starting'                                       = 'Starting execution' #
    'Save-AzOpsManagementGroupChild.Subscription.NotFound'                          = 'Unable to locate subscription: {0} within AzOpsSubscriptions object' #child.Name

    'Search-AzOpsAzGraph.Processing'                                                = 'AzGraph processing query: [{0}]' # $Query
    'Search-AzOpsAzGraph.Processing.Done'                                           = 'AzGraph completed processing of query: [{0}]' # $Query
    'Search-AzOpsAzGraph.Processing.NoResult'                                       = 'AzGraph found nothing with query: [{0}]' # $Query

    'Set-AzOpsContext.Change'                                                       = 'Changing active subscription from {0} to {1} ({2})' # $context.Subscription.Name, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription

    'Set-AzOpsStringLength.Shortened'                                               = 'New shortened string {0} in-line with limit of {1}' # $String, $MaxStringLength
    'Set-AzOpsStringLength.ToLong'                                                  = 'String {0} exceeding limit of {1} by {2} characters' # $String, $MaxStringLength, $overSize
    'Set-AzOpsStringLength.WithInLimit'                                             = 'String {0} within limit of {1}' # $String

    'Set-AzOpsWhatIfOutput.WhatIfFile'                                              = 'Creating WhatIf markdown and json files' #
    'Set-AzOpsWhatIfOutput.WhatIfFileAdding'                                        = 'Adding content to WhatIf {0} file for template {1} with parameter file {2}' # '<type>', $FilePath, $ParameterFilePath
    'Set-AzOpsWhatIfOutput.WhatIfFileMax'                                           = 'WhatIf markdown and json files have reached character limit, unable to append more information to files. WhatIf is too large for comment field, for more details look at PR files to determine changes.' # $ResultSizeMaxLimit, $ResultSizeLimit
    'Set-AzOpsWhatIfOutput.WhatIfMessageMax'                                        = 'WhatIf have reached maximum character limit, unable to append warning message. WhatIf is too large for comment field, for more details look at PR files to determine changes.' # $ResultSizeMaxLimit, $ResultSizeLimit
    'Set-AzOpsWhatIfOutput.WhatIfResults'                                           = 'WhatIf Output {0}' # $results
    'Set-AzOpsWhatIfOutput.WhatIfFile.Remove'                                       = 'Removing WhatIf markdown and json files lingering from previous run' #
}