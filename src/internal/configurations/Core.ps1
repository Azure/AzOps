﻿Set-PSFConfig -Module AzOps -Name Core.AllInOneTemplate -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.AutoGeneratedTemplateFolderPath -Value "." -Initialize -Validation string -Description 'Auto-Genereated Template Folder Path i.e. ./Az'
Set-PSFConfig -Module AzOps -Name Core.AutoInitialize -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.DefaultDeploymentRegion -Value northeurope -Initialize -Validation string -Description 'Default deployment region for state deployments (ARM region, not region where a resource is deployed)'
Set-PSFConfig -Module AzOps -Name Core.EnrollmentAccountPrincipalName -Value '' -Initialize -Validation stringorempty -Description '-'
Set-PSFConfig -Module AzOps -Name Core.ExcludedSubOffer -Value 'AzurePass_2014-09-01', 'FreeTrial_2014-09-01', 'AAD_2015-09-01' -Initialize -Validation stringarray -Description 'Excluded QuotaID'
Set-PSFConfig -Module AzOps -Name Core.ExcludedSubState -Value 'Disabled', 'Deleted', 'Warned', 'Expired' -Initialize -Validation stringarray -Description 'Excluded subscription states'
Set-PSFConfig -Module AzOps -Name Core.IgnoreContextCheck -Value $false -Initialize -Validation bool -Description 'If set to $true, skip AAD tenant validation == 1'
Set-PSFConfig -Module AzOps -Name Core.InvalidateCache -Value $true -Initialize -Validation bool -Description 'Invalidates cache and ensures that Management Groups and Subscriptions are re-discovered'
Set-PSFConfig -Module AzOps -Name Core.JqTemplatePath -Value "$script:ModuleRoot\data\template" -Initialize -Validation string -Description 'default path to search for jq template'
Set-PSFConfig -Module AzOps -Name Core.MainTemplate -Value "$script:ModuleRoot\data\template\template.json" -Initialize -Validation string -Description 'Main template json'
Set-PSFConfig -Module AzOps -Name Core.OfferType -Value 'MS-AZR-0017P' -Initialize -Validation string -Description '-'
Set-PSFConfig -Module AzOps -Name Core.PartialMgDiscoveryRoot -Value @() -Initialize -Validation stringarray -Description 'Used in combination with AZOPS_SUPPORT_PARTIAL_MG_DISCOVERY, example value: "Contoso","Tailspin","Management"'
Set-PSFConfig -Module AzOps -Name Core.SkipPolicy -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.SkipResource -Value $true -Initialize -Validation bool -Description 'Global flag to indicate whether resource should be discovered or not. Requires SkipResourceGroup to be false.'
Set-PSFConfig -Module AzOps -Name Core.SkipResourceGroup -Value $false -Initialize -Validation bool -Description 'Global flag to indicate whether resource group should be discovered or not'
Set-PSFConfig -Module AzOps -Name Core.SkipRole -Value $false -Initialize -Validation bool -Description '-'
Set-PSFConfig -Module AzOps -Name Core.State -Value (Join-Path $pwd -ChildPath "root") -Initialize -Validation string -Description 'Folder to store AzOpsState artefact'
Set-PSFConfig -Module AzOps -Name Core.SubscriptionsToIncludeResourceGroups -Value @('*') -Initialize -Validation stringarray -Description 'Requires SkipResourceGroup to be false. Subscription ID or Display Name that matches the filter. Powershell filter that matches with like operator is supported.'
Set-PSFConfig -Module AzOps -Name Core.TemplateParameterFileSuffix -Value '.json' -Initialize -Validation string -Description 'parameter file suffix to look for'
Set-PSFConfig -Module AzOps -Name Core.ThrottleLimit -Value 10 -Initialize -Validation integer -Description 'Throttle limit used in Foreach-Object -Parallel for resource/subscription discovery'