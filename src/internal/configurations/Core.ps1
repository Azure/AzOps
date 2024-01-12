﻿Set-PSFConfig -Module AzOps -Name Core.ApplicationInsights -Value $false -Initialize -Validation bool -Description 'Global flag to turn on or off logging to Application Insight'
Set-PSFConfig -Module AzOps -Name Core.AutoGeneratedTemplateFolderPath -Value "." -Initialize -Validation string -Description 'Auto-Generated Template Folder Path i.e. ./Az'
Set-PSFConfig -Module AzOps -Name Core.AutoInitialize -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.DeletionSupportedResourceType -Value @('Microsoft.Authorization/locks', 'locks', 'Microsoft.Authorization/policyAssignments', 'policyAssignments', 'Microsoft.Authorization/policyDefinitions', 'policyDefinitions', 'Microsoft.Authorization/policyExemptions', 'policyExemptions', 'Microsoft.Authorization/policySetDefinitions', 'policySetDefinitions', 'Microsoft.Authorization/roleAssignments', 'roleAssignments') -Initialize -Validation stringarray -Description 'Global flag declaring resource types supported for deletion by AzOps.'
Set-PSFConfig -Module AzOps -Name Core.DefaultDeploymentRegion -Value northeurope -Initialize -Validation string -Description 'Default deployment region for state deployments (ARM region, not region where a resource is deployed)'
Set-PSFConfig -Module AzOps -Name Core.EnrollmentAccountPrincipalName -Value '' -Initialize -Validation stringorempty -Description '-'
Set-PSFConfig -Module AzOps -Name Core.ExcludedSubOffer -Value 'AzurePass_2014-09-01', 'FreeTrial_2014-09-01', 'AAD_2015-09-01' -Initialize -Validation stringarray -Description 'Excluded QuotaID'
Set-PSFConfig -Module AzOps -Name Core.ExcludedSubState -Value 'Disabled', 'Deleted', 'Warned', 'Expired' -Initialize -Validation stringarray -Description 'Excluded subscription states'
Set-PSFConfig -Module AzOps -Name Core.IgnoreContextCheck -Value $false -Initialize -Validation bool -Description 'If set to $true, skip AAD tenant validation == 1'
Set-PSFConfig -Module AzOps -Name Core.InvalidateCache -Value $true -Initialize -Validation bool -Description 'Invalidates cache and ensures that Management Groups and Subscriptions are re-discovered'
Set-PSFConfig -Module AzOps -Name Core.JqTemplatePath -Value "$script:ModuleRoot\data\template" -Initialize -Validation string -Description 'Default path to search for jq template'
Set-PSFConfig -Module AzOps -Name Core.CustomJqTemplatePath -Value (Join-Path $pwd -ChildPath ".customtemplates") -Initialize -Validation string -Description 'Optional custom path to search for custom jq template'
Set-PSFConfig -Module AzOps -Name Core.SkipCustomJqTemplate -Value $true -Initialize -Validation bool -Description 'Controls usage of CustomJqTemplatePath to search for custom jq template'
Set-PSFConfig -Module AzOps -Name Core.MainTemplate -Value "$script:ModuleRoot\data\template\template.json" -Initialize -Validation string -Description 'Main template json'
Set-PSFConfig -Module AzOps -Name Core.OfferType -Value 'MS-AZR-0017P' -Initialize -Validation string -Description '-'
Set-PSFConfig -Module AzOps -Name Core.PartialMgDiscoveryRoot -Value @() -Initialize -Validation stringarray -Description 'Used in combination with AZOPS_SUPPORT_PARTIAL_MG_DISCOVERY, example value: "Contoso","Tailspin","Management"'
Set-PSFConfig -Module AzOps -Name Core.IncludeResourcesInResourceGroup -Value @('*') -Initialize -Validation stringarray -Description 'Global flag to discover only resources in these resource groups.'
Set-PSFConfig -Module AzOps -Name Core.IncludeResourceType -Value @('*') -Initialize -Validation stringarray -Description 'Global flag to discover only specific resource types.'
Set-PSFConfig -Module AzOps -Name Core.SkipChildResource -Value $true -Initialize -Validation bool -Description 'Global flag to indicate whether child resources should be discovered or not. Requires SkipResourceGroup and SkipResource to be false.'
Set-PSFConfig -Module AzOps -Name Core.SkipPim -Value $true -Initialize -Validation bool -Description 'Global flag to control discovery of Privileged Identity Management resources.'
Set-PSFConfig -Module AzOps -Name Core.SkipLock -Value $true -Initialize -Validation bool -Description 'Global flag to control discovery of resource lock resources.'
Set-PSFConfig -Module AzOps -Name Core.SkipPolicy -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.SkipResource -Value $true -Initialize -Validation bool -Description 'Global flag to indicate whether resource should be discovered or not. Requires SkipResourceGroup to be false.'
Set-PSFConfig -Module AzOps -Name Core.SkipResourceGroup -Value $false -Initialize -Validation bool -Description 'Global flag to indicate whether resource group should be discovered or not'
Set-PSFConfig -Module AzOps -Name Core.SkipResourceType -Value @('Microsoft.VSOnline/plans', 'Microsoft.PowerPlatform/accounts', 'Microsoft.PowerPlatform/enterprisePolicies') -Initialize -Validation stringarray -Description 'Global flag to skip discovery of specific Resource types.'
Set-PSFConfig -Module AzOps -Name Core.SkipRole -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.State -Value (Join-Path $pwd -ChildPath "root") -Initialize -Validation string -Description 'Folder to store AzOpsState artefact'
Set-PSFConfig -Module AzOps -Name Core.SubscriptionsToIncludeResourceGroups -Value @('*') -Initialize -Validation stringarray -Description 'Requires SkipResourceGroup to be false. Subscription ID or Display Name that matches the filter. Powershell filter that matches with like operator is supported.'
Set-PSFConfig -Module AzOps -Name Core.TemplateParameterFileSuffix -Value '.json' -Initialize -Validation string -Description 'Parameter file suffix identifier'
Set-PSFConfig -Module AzOps -Name Core.AllowMultipleTemplateParameterFiles -Value $false -Initialize -Validation string -Description 'Global flag to control multiple parameter file behaviour'
Set-PSFConfig -Module AzOps -Name Core.DeployAllMultipleTemplateParameterFiles -Value $false -Initialize -Validation string -Description 'Global flag to control base template deployment behaviour with changes and un-changed multiple corresponding parameter files'
Set-PSFConfig -Module AzOps -Name Core.MultipleTemplateParameterFileSuffix -Value '.x' -Initialize -Validation string -Description 'Multiple parameter file suffix identifier'
Set-PSFConfig -Module AzOps -Name Core.ParallelDeployMultipleTemplateParameterFiles -Value $false -Initialize -Validation string -Description 'Global flag to control parallel deployment of MultipleTemplateParameterFiles behaviour'
Set-PSFConfig -Module AzOps -Name Core.ThrottleLimit -Value 5 -Initialize -Validation integer -Description 'Throttle limit used in Foreach-Object -Parallel for resource/subscription discovery'
Set-PSFConfig -Module AzOps -Name Core.WhatifExcludedChangeTypes -Value @('NoChange', 'Ignore') -Initialize -Validation stringarray -Description 'Exclude specific change types from WhatIf operations.'