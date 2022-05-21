﻿
#
# Repository.Tests.ps1
#
# The tests within this file validate
# that the `Invoke-AzOpsPull`
# function is invoking as expected with
# the correct output data.
#
# This file must be invoked by the Pester.ps1
# file as the Global variable testroot is
# required for invocation.
#

Describe "Repository" {

    BeforeAll {

        Write-PSFMessage -Level Verbose -Message "Initializing test environment" -FunctionName "BeforeAll"

        #
        # Set the error preference
        #

        $ErrorActionPreference = "Stop"

        # Suppress the breaking change warning messages in Azure PowerShell
        Set-Item -Path  Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

        #
        # Script Isolation
        # https://github.com/pester/Pester/releases/tag/5.2.0
        #

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        #
        # Validate that the runtime variables
        # are set as they are used to authenticate
        # the Azure session.
        #

        if ($null -eq $script:tenantId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_TENANT_ID"
            throw
        }
        if ($null -eq $script:subscriptionId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_SUBSCRIPTION_ID"
            throw
        }

        #
        # Ensure PowerShell has an authenticate
        # Azure Context which the tests can
        # run within and generate data as needed
        #

        Write-PSFMessage -Level Verbose -Message "Validating Azure context" -FunctionName "BeforeAll"
        $tenant = (Get-AzContext -ListAvailable -ErrorAction SilentlyContinue).Tenant.Id
        if ($tenant -inotcontains "$script:tenantId") {
            Write-PSFMessage -Level Verbose -Message "Authenticating Azure session" -FunctionName "BeforeAll"
            if ($env:USER -eq "vsts") {
                # Platform: Azure Pipelines
                $credential = New-Object PSCredential -ArgumentList $env:ARM_CLIENT_ID, (ConvertTo-SecureString -String $env:ARM_CLIENT_SECRET -AsPlainText -Force)
                $null = Connect-AzAccount -TenantId $script:tenantId -ServicePrincipal -Credential $credential -SubscriptionId $script:subscriptionId -WarningAction SilentlyContinue
            }
        }
        else {
            $null = Set-AzContext -TenantId $script:tenantId -SubscriptionId $script:subscriptionId
        }

        #
        # Deploy the Azure environment
        # based upon prefined resource templates
        # which will generate a matching
        # file system hierachy
        #

        Write-PSFMessage -Level Verbose -Message "Creating Management Group structure" -FunctionName "BeforeAll"
        $templateFile = Join-Path -Path $global:testroot -ChildPath "templates/azuredeploy.jsonc"
        $templateParameters = @{
            "tenantId"       = "$script:tenantId"
            "subscriptionId" = "$script:subscriptionId"
        }
        $params = @{
            ManagementGroupId       = "$script:tenantId"
            Name                    = "AzOps-Tests"
            TemplateFile            = "$templateFile"
            TemplateParameterObject = $templateParameters
            Location                = "northeurope"
        }
        try {
            New-AzManagementGroupDeployment @params
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
            throw
        }

        <#
        Wait for Management Group structure consistency
        #>

        $script:managementGroupDeployment = (Get-AzManagementGroupDeployment -ManagementGroupId "$script:tenantId" -Name "AzOps-Tests")
        $script:timeOutMinutes = 30
        $script:mgmtRun = "Run"

        While ($script:mgmtRun -eq "Run") {
            Write-PSFMessage -Level Verbose -Message "Waiting for Management Group structure consistency" -FunctionName "BeforeAll"

            $script:mgmt = Get-AzManagementGroup
            $script:testManagementGroup = ($script:mgmt | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.testManagementGroup.value)")
            $script:platformManagementGroup = ($script:mgmt | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.platformManagementGroup.value)")
            $script:managementManagementGroup = ($script:mgmt | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.managementManagementGroup.value)")

            if ($script:testManagementGroup -ne $null -and $script:platformManagementGroup -ne $null -and $script:managementManagementGroup -ne $null) {
                $script:mgmtRun = "Done"
            }
            else {
                Start-Sleep -Seconds 60
                $script:timeOutMinutes--
            }
            if ($script:timeOutMinutes -le 0) {
                break
            }
        }

        #
        # Ensure that the root directory
        # does not exist before running
        # tests.
        #

        Write-PSFMessage -Level Verbose -Message "Testing for root directory existence" -FunctionName "BeforeAll"
        $generatedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        if (Test-Path -Path $generatedRoot) {
            Write-PSFMessage -Level Verbose -Message "Removing root directory" -FunctionName "BeforeAll"
            Remove-Item -Path $generatedRoot -Recurse
        }

        #
        # The following values match the Resource Template
        # which we deploy the platform services with
        # these need to match so that the lookups within
        # the filesystem are aligned.
        #

        try {
            Start-Sleep -Seconds 120
            Set-AzContext -SubscriptionId $script:subscriptionId
            $script:policyAssignments = Get-AzPolicyAssignment -Name "TestPolicyAssignment" -Scope "/providers/Microsoft.Management/managementGroups/$($script:managementManagementGroup.Name)"
            $script:subscription = (Get-AzSubscription | Where-Object Id -eq $script:subscriptionId)
            $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq "Application")
            $script:roleAssignments = (Get-AzRoleAssignment -ObjectId "023e7c1c-1fa4-4818-bb78-0a9c5e8b0217" | Where-Object { $_.Scope -eq "/subscriptions/$script:subscriptionId" -and $_.RoleDefinitionId -eq "acdd72a7-3385-48ef-bd42-f606fba81ae7" })
            $script:policyExemptions = Get-AzPolicyExemption -Name "PolicyExemptionTest" -Scope "/subscriptions/$script:subscriptionId"
            $script:routeTable = (Get-AzResource -Name "RouteTable" -ResourceGroupName $($script:resourceGroup).ResourceGroupName)
            $script:ruleCollectionGroups = (Get-AzResource -ExpandProperties -Name "TestPolicy" -ResourceGroupName $($script:resourceGroup).ResourceGroupName).Properties.ruleCollectionGroups.id.split("/")[-1]
            $script:logAnalyticsWorkspace = (Get-AzResource -Name "thisisalongloganalyticsworkspacename123456789011121314151617181" -ResourceGroupName $($script:resourceGroup).ResourceGroupName)
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Failed to get deployed services" -Exception $_.Exception
        }

        #
        # Invoke the Invoke-AzOpsPull
        # function to generate the scope data which
        # can be tested against to ensure structure
        # is correct and data model hasn't changed.
        #

        Set-PSFConfig -FullName AzOps.Core.SubscriptionsToIncludeResourceGroups -Value $script:subscriptionId
        Set-PSFConfig -FullName AzOps.Core.SkipChildResource -Value $false
        Set-PSFConfig -FullName AzOps.Core.DefaultDeploymentRegion -Value "northeurope"
        $deploymentLocationId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)

        Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "BeforeAll"
        try {
            Invoke-AzOpsPull -SkipRole:$false -SkipPolicy:$false -SkipResource:$false
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }

        #
        # The following values are discovering the file
        # system paths so that they can be validate against
        # ensuring that the data model hasn't altered.
        # If the model has been changed these tests will
        # need to be updated and a major version increment.
        #

        #region Paths
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $generatedRoot" -FunctionName "BeforeAll"

        $filePaths = (Get-ChildItem -Path $generatedRoot -Recurse)

        $script:tenantRootGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$(($script:tenantId).toLower()).json")
        $script:tenantRootGroupDirectory = ($script:tenantRootGroupPath).Directory
        $script:tenantRootGroupFile = ($script:tenantRootGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TenantRootGroupPath: $($script:tenantRootGroupFile)" -FunctionName "BeforeAll"

        $script:testManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$(($script:testManagementGroup.Name).toLower()).json")
        $script:testManagementGroupDirectory = ($script:testManagementGroupPath).Directory
        $script:testManagementGroupFile = ($script:testManagementGroupPath).FullName
        $script:testManagementGroupDeploymentName = "AzOps-{0}-{1}" -f $($script:testManagementGroupPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "TestManagementGroupFile: $($script:testManagementGroupFile)" -FunctionName "BeforeAll"

        $script:platformManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$(($script:platformManagementGroup.Name).toLower()).json")
        $script:platformManagementGroupDirectory = ($script:platformManagementGroupPath).Directory
        $script:platformManagementGroupFile = ($script:platformManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "PlatformManagementGroupFile: $($script:platformManagementGroupFile)" -FunctionName "BeforeAll"

        $script:managementManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$(($script:managementManagementGroup.Name).toLower()).json")
        $script:managementManagementGroupDirectory = ($script:managementManagementGroupPath).Directory
        $script:managementManagementGroupFile = ($script:managementManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ManagementManagementGroupFile: $($script:managementManagementGroupFile)" -FunctionName "BeforeAll"

        $script:policyAssignmentsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policyassignments-$(($script:policyAssignments.Name).toLower()).json")
        $script:policyAssignmentsDirectory = ($script:policyAssignmentsPath).Directory
        $script:policyAssignmentsFile = ($script:policyAssignmentsPath).FullName
        $script:policyAssignmentsDeploymentName = "AzOps-{0}-{1}" -f $($script:policyAssignmentsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyAssignmentsFile: $($script:policyAssignmentsFile)" -FunctionName "BeforeAll"

        $script:subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$(($script:subscription.Id).toLower()).json")
        $script:subscriptionDirectory = ($script:subscriptionPath).Directory
        $script:subscriptionFile = ($script:subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName "BeforeAll"

        $script:resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$(($script:resourceGroup.ResourceGroupName).toLower()).json")
        $script:resourceGroupDirectory = ($script:resourceGroupPath).Directory
        $script:resourceGroupFile = ($script:resourceGroupPath).FullName
        $script:resourceGroupDeploymentName = "AzOps-{0}-{1}" -f $($script:resourceGroupPath.Name.Replace(".json", '')), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "ResourceGroupFile: $($script:resourceGroupFile)" -FunctionName "BeforeAll"

        $script:roleAssignmentsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_roleassignments-$(($script:roleAssignments.RoleAssignmentId).toLower() -replace ".*/").json")
        $script:roleAssignmentsDirectory = ($script:roleAssignmentsPath).Directory
        $script:roleAssignmentsFile = ($script:roleAssignmentsPath).FullName
        $script:roleAssignmentsDeploymentName = "AzOps-{0}-{1}" -f $($script:roleAssignmentsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "RoleAssignmentFile: $($script:roleAssignmentsFile)" -FunctionName "BeforeAll"

        $script:policyExemptionsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policyexemptions-$(($script:policyExemptions.Name).toLower()).json")
        $script:policyExemptionsDirectory = ($script:policyExemptionsPath).Directory
        $script:policyExemptionsFile = ($script:policyExemptionsPath).FullName
        $script:policyExemptionsDeploymentName = "AzOps-{0}-{1}" -f $($script:policyExemptionsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyAssignmentFile: $($script:policyExemptionsFile)" -FunctionName "BeforeAll"

        $script:routeTablePath = ($filePaths | Where-Object Name -eq "microsoft.network_routetables-$(($script:routeTable.Name).toLower()).json")
        $script:routeTableDirectory = ($script:routeTablePath).Directory
        $script:routeTableFile = ($script:routeTablePath).FullName
        $script:routeTableDeploymentName = "AzOps-{0}-{1}" -f $($script:routeTablePath.Name.Replace(".json", '')), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "RouteTableFile: $($script:routeTableFile)" -FunctionName "BeforeAll"

        $script:ruleCollectionGroupsPath = ($filePaths | Where-Object Name -eq "microsoft.network_firewallpolicies_rulecollectiongroups-testpolicy_$(($script:ruleCollectionGroups).toLower()).json")
        $script:ruleCollectionGroupsDirectory = ($script:ruleCollectionGroupsPath).Directory
        $script:ruleCollectionGroupsFile = ($script:ruleCollectionGroupsPath).FullName
        $script:ruleCollectionDeploymentName = "AzOps-{0}-{1}" -f $($script:ruleCollectionGroupsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "RuleCollectionGroupsFile: $($script:ruleCollectionGroupsFile)" -FunctionName "BeforeAll"

        $script:logAnalyticsWorkspaceSavedSearchesPath = ($filePaths | Where-Object Name -eq "microsoft.operationalinsights_workspaces_savedsearches-$(($script:logAnalyticsWorkspace.Name).toLower())_logmanagement(thisisalongloganalyticsworkspacename12345-ee7c6e90e26a87cec75b83b2ed548077fed5750162e50d80fdda5d8ce27f3478.json")
        $script:logAnalyticsWorkspaceSavedSearchesDirectory = ($script:logAnalyticsWorkspaceSavedSearchesPath).Directory
        $script:logAnalyticsWorkspaceSavedSearchesFile = ($script:logAnalyticsWorkspaceSavedSearchesPath).FullName
        Write-PSFMessage -Level Debug -Message "logAnalyticsWorkspaceSavedSearchesFile: $($script:logAnalyticsWorkspaceSavedSearchesFile)" -FunctionName "BeforeAll"

        $script:bicepTemplatePath = Get-ChildItem -Path "$($global:testRoot)/templates/bicep*" | Copy-Item -Destination $script:subscriptionDirectory -PassThru -Force
        $script:bicepDeploymentName = "AzOps-{0}-{1}" -f $($script:bicepTemplatePath[0].Name.Replace(".bicep", '')), $deploymentLocationId
        $script:bicepResourceGroupName = ((Get-Content -Path ($Script:bicepTemplatePath.FullName[1])) | ConvertFrom-Json).parameters.resourceGroupName.value
        #endregion Paths

        #Test push based on pulled resources
        $changeSet = @(
            "A`t$script:testManagementGroupFile",
            "A`t$script:policyAssignmentsFile",
            "A`t$script:policyExemptionsFile",
            "A`t$script:roleAssignmentsFile",
            "A`t$script:resourceGroupFile",
            "A`t$script:routeTableFile",
            "A`t$script:ruleCollectionGroupsFile"
            "A`t$($script:bicepTemplatePath.FullName[0])"
        )
        Invoke-AzOpsPush -ChangeSet $changeSet

        #Test deletion of supported resources
        $changeSet = @(
            "D`t$script:policyAssignmentsFile",
            "D`t$script:policyExemptionsFile",
            "D`t$script:roleAssignmentsFile"
        )
        $DeleteSetContents += (Get-Content $Script:policyAssignmentsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:policyExemptionsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:roleAssignmentsFile)
        Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents
    }

    Context "Test" {

        #
        # Script Isolation
        # https://github.com/pester/Pester/releases/tag/5.2.0
        #

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        #region
        # Scope - Root (./root)
        It "Root directory should exist" {
            Test-Path -Path $generatedRoot | Should -BeTrue
        }
        #endregion

        #region Scope - Tenant Root Group (./root/tenant root group)
        It "Tenant Root Group directory should exist" {
            Test-Path -Path $script:tenantRootGroupDirectory | Should -BeTrue
        }
        It "Tenant Root Group file should exist" {
            Test-Path -Path $script:tenantRootGroupFile | Should -BeTrue
        }
        It "Tenant Root Group resource type should exist" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Tenant Root Group resource name should exist" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Tenant Root Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Tenant Root Group resource properties should exist" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Tenant Root Group resource type should match" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        }
        It "Tenant Root Group scope property should match" {
            $fileContents = Get-Content -Path $script:tenantRootGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
        }
        #endregion

        #region Scope - Management Group (./root/tenant root group/test/)
        It "Management Group directory should exist" {
            Test-Path -Path $script:testManagementGroupDirectory | Should -BeTrue
        }
        It "Management Group file should exist" {
            Test-Path -Path $script:testManagementGroupFile | Should -BeTrue
        }
        It "Management Group resource type should exist" {
            $fileContents = Get-Content -Path $script:testManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Management Group resource name should exist" {
            $fileContents = Get-Content -Path $script:testManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Management Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:testManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Management Group resource type should match" {
            $fileContents = Get-Content -Path $script:testManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        }
        It "Management Group scope property should match" {
            $fileContents = Get-Content -Path $script:testManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
        }
        It "Management group deployment should be successful" {
            $script:managementGroupDeployment = Get-AzManagementGroupDeployment -ManagementGroupId $script:testManagementGroup.Name -Name $script:testManagementGroupDeploymentName
            $managementGroupDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Scope - Management Group (./root/tenant root group/test/platform/)
        It "Management Group directory should exist" {
            Test-Path -Path $script:platformManagementGroupDirectory | Should -BeTrue
        }
        It "Management Group file should exist" {
            Test-Path -Path $script:platformManagementGroupFile | Should -BeTrue
        }
        It "Management Group resource type should exist" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Management Group resource name should exist" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Management Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Management Group resource properties should exist" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Management Group resource type should match" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        }
        It "Management Group scope property should match" {
            $fileContents = Get-Content -Path $script:platformManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
        }
        #endregion

        #region Scope = Management Group (./root/tenant root group/test/platform/management/)
        It "Management Group directory should exist" {
            Test-Path -Path $script:managementManagementGroupDirectory | Should -BeTrue
        }
        It "Management Group file should exist" {
            Test-Path -Path $script:managementManagementGroupFile | Should -BeTrue
        }
        It "Management Group resource type should exist" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Management Group resource name should exist" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Management Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Management Group resource properties should exist" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Management Group resource type should match" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        }
        It "Management Group scope property should match" {
            $fileContents = Get-Content -Path $script:managementManagementGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
        }
        #endregion

        #region Scope = Policy Assignments (./root/tenant root group/test/platform/management/PolicyAssignment)
        It "Policy Assignments directory should exist" {
            Test-Path -Path $script:policyAssignmentsDirectory | Should -BeTrue
        }
        It "Policy Assignments file should exist" {
            Test-Path -Path $script:policyAssignmentsFile | Should -BeTrue
        }
        It "Policy Assignments resource type should exist" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Policy Assignments resource name should exist" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Policy Assignments resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Policy Assignments resource properties should exist" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Policy Assignments resource type should match" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Authorization/policyAssignments"
        }
        It "Policy Assignments scope property should match" {
            $fileContents = Get-Content -Path $script:policyAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties.scope | Should -Be "$($script:managementManagementGroup.Id)"
        }
        It "Policy Assignments deployment should be successful" {
            $script:policyAssignmentDeployment = Get-AzManagementGroupDeployment -ManagementGroupId $script:managementManagementGroup.Name -Name $script:policyAssignmentsDeploymentName
            $policyAssignmentDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "Policy Assignments deletion should be successful" {
            $policyAssignmentDeletion = Get-AzPolicyAssignment -Id $script:policyAssignments.PolicyAssignmentId -ErrorAction SilentlyContinue
            $policyAssignmentDeletion | Should -Be $Null
        }
        #endregion

        #region Scope - Subscription (./root/tenant root group/test/platform/management/subscription-0)
        It "Subscription directory should exist" {
            Test-Path -Path $script:subscriptionDirectory | Should -BeTrue
        }
        It "Subscription file should exist" {
            Test-Path -Path $script:subscriptionFile | Should -BeTrue
        }
        It "Subscription resource type should exist" {
            $fileContents = Get-Content -Path $script:subscriptionFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Subscription resource name should exist" {
            $fileContents = Get-Content -Path $script:subscriptionFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Subscription resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:subscriptionFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Subscription resource type should match" {
            $fileContents = Get-Content -Path $script:subscriptionFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups/subscriptions"
        }
        It "Subscription scope should match" {
            $fileContents = Get-Content -Path $script:subscriptionFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
        }
        #endregion

        #region Scope - Resource Group (./root/tenant root group/test/platform/management/subscription-0/application)
        It "Resource Group directory should exist" {
            Test-Path -Path $script:resourceGroupDirectory | Should -BeTrue
        }
        It "Resource Group file should exist" {
            Test-Path -Path $script:resourceGroupFile | Should -BeTrue
        }
        It "Resource Group resource type should exist" {
            $fileContents = Get-Content -Path $script:resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Resource Group resource name should exist" {
            $fileContents = Get-Content -Path $script:resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Resource Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Resource Group resource properties should exist" {
            $fileContents = Get-Content -Path $script:resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Resource Group resource type should match" {
            $fileContents = Get-Content -Path $script:resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Resources/resourceGroups"
        }
        It "Resource Group deployment should be successful" {
            $script:resourceGroupDeployment = Get-AzSubscriptionDeployment -Name $script:resourceGroupDeploymentName
            $resourceGroupDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Deploy Resource Group via bicep
        It "Bicep deployment should be successful" {
            $script:bicepDeployment = Get-AzSubscriptionDeployment -Name $script:bicepDeploymentName
            $bicepDeployment.ProvisioningState | Should -Be "Succeeded"
        }

        It "Resource Group deployed through bicep should exist" {
            $script:bicepResourceGroup = Get-AzResourceGroup -ResourceGroupName $script:bicepResourceGroupName
            $bicepResourceGroup.ResourceGroupName | Should -Be $script:bicepResourceGroupName
        }
        #endregion

        #region Scope - Role Assignment (./root/tenant root group/test/platform/management/subscription-0/roleassignments)
        It "Role Assignment directory should exist" {
            Test-Path -Path $script:roleAssignmentsDirectory | Should -BeTrue
        }
        It "Role Assignment file should exist" {
            Test-Path -Path $script:roleAssignmentsFile | Should -BeTrue
        }
        It "Role Assignment resource type should exist" {
            $fileContents = Get-Content -Path $script:roleAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Role Assignment resource name should exist" {
            $fileContents = Get-Content -Path $script:roleAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Role Assignment resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:roleAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Role Assignment resource properties should exist" {
            $fileContents = Get-Content -Path $script:roleAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Role Assignment resource type should match" {
            $fileContents = Get-Content -Path $script:roleAssignmentsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Authorization/roleAssignments"
        }
        It "Role Assignment deployment should be successful" {
            $script:roleAssignmentDeployment = Get-AzSubscriptionDeployment -Name $script:roleAssignmentsDeploymentName
            $roleAssignmentDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "Role Assignment deletion should be successful" {
            $roleAssignmentDeletion = (Get-AzRoleAssignment -ObjectId "023e7c1c-1fa4-4818-bb78-0a9c5e8b0217" | Where-Object { $_.Scope -eq "/subscriptions/$script:subscriptionId" -and $_.RoleDefinitionId -eq "acdd72a7-3385-48ef-bd42-f606fba81ae7" })
            $roleAssignmentDeletion | Should -Be $Null
        }
        #endregion

        #region Scope - Policy Exemptions (./root/tenant root group/test/platform/management/subscription-0/policyexemptions)
        It "Policy Exemption directory should exist" {
            Test-Path -Path $script:policyExemptionsDirectory | Should -BeTrue
        }
        It "Policy Exemption file should exist" {
            Test-Path -Path $script:policyExemptionsFile | Should -BeTrue
        }
        It "Policy Exemption resource type should exist" {
            $fileContents = Get-Content -Path $script:policyExemptionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Policy Exemption resource name should exist" {
            $fileContents = Get-Content -Path $script:policyExemptionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Policy Exemption resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:policyExemptionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Policy Exemption resource properties should exist" {
            $fileContents = Get-Content -Path $script:policyExemptionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Policy Exemption resource type should match" {
            $fileContents = Get-Content -Path $script:policyExemptionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Authorization/policyExemptions"
        }
        It "Policy Exemption deployment should be successful" {
            $script:policyExemptionDeployment = Get-AzSubscriptionDeployment -Name $script:policyExemptionsDeploymentName
            $policyExemptionDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "Policy Exemption deletion should be successful" {
            $policyExemptionDeletion = (Get-AzPolicyExemption -Name "PolicyExemptionTest" -Scope "/subscriptions/$script:subscriptionId" -ErrorAction SilentlyContinue)
            $policyExemptionDeletion | Should -Be $Null
        }
        #endregion

        #region Scope - Route Table (./root/tenant root group/test/platform/management/subscription-0/application/routetable)
        It "Route Table directory should exist" {
            Test-Path -Path $script:routeTableDirectory | Should -BeTrue
        }
        It "Route Table file should exist" {
            Test-Path -Path $script:routeTableFile | Should -BeTrue
        }
        It "Route Table resource type should exist" {
            $fileContents = Get-Content -Path $script:routeTableFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Route Table resource name should exist" {
            $fileContents = Get-Content -Path $script:routeTableFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Route Table resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:routeTableFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Route Table resource properties should exist" {
            $fileContents = Get-Content -Path $script:routeTableFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Route Table resource type should match" {
            $fileContents = Get-Content -Path $script:routeTableFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Network/routeTables"
        }
        It "Route Table deployment should be successful" {
            $script:routeTableDeployment = Get-AzResourceGroupDeployment -ResourceGroupName 'Application' -Name $script:routeTableDeploymentName
            $routeTableDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Scope - ruleCollectionGroup (./root/tenant root group/test/platform/management/subscription-0/application/testpolicy/testgroup)
        It "Rule Collection Group directory should exist" {
            Test-Path -Path $script:ruleCollectionGroupsDirectory | Should -BeTrue
        }
        It "Rule Collection Group file should exist" {
            Test-Path -Path $script:ruleCollectionGroupsFile | Should -BeTrue
        }
        It "Rule Collection Group resource type should exist" {
            $fileContents = Get-Content -Path $script:ruleCollectionGroupsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Rule Collection Group resource name should exist" {
            $fileContents = Get-Content -Path $script:ruleCollectionGroupsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Rule Collection Group resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:ruleCollectionGroupsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Rule Collection Group resource properties should exist" {
            $fileContents = Get-Content -Path $script:ruleCollectionGroupsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Rule Collection Group resource type should match" {
            $fileContents = Get-Content -Path $script:ruleCollectionGroupsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Network/firewallPolicies/ruleCollectionGroups"
        }
        It "Rule Collection Group deployment should be successful" {
            $script:ruleCollectionDeployment = Get-AzResourceGroupDeployment -ResourceGroupName 'Application' -Name $script:ruleCollectionDeploymentName
            $ruleCollectionDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Scope - logAnalyticsWorkspaceSavedSearchesPath (./root/tenant root group/test/platform/management/subscription-0/application/thisisalongloganalyticsworkspacename123456789011121314151617181)
        It "LogAnalyticsWorkspaceSavedSearches directory should exist" {
            Test-Path -Path $script:logAnalyticsWorkspaceSavedSearchesDirectory | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches file should exist" {
            Test-Path -Path $script:logAnalyticsWorkspaceSavedSearchesFile | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource type should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource name should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource properties should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource type should match" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.OperationalInsights/workspaces/savedSearches"
        }
        #endregion
    }

    AfterAll {

        function Remove-ManagementGroups {

            param (
                [Parameter()]
                [string]
                $DisplayName,

                [Parameter()]
                [string]
                $Name,

                [Parameter()]
                [string]
                $RootName
            )

            process {
                # Retrieve list of children within the provided Management Group Id
                $children = (Get-AzManagementGroup -GroupId $Name -Expand -Recurse -WarningAction SilentlyContinue).Children

                if ($children) {
                    $children | ForEach-Object {
                        if ($_.Type -eq "/providers/Microsoft.Management/managementGroups") {
                            # Invoke function again with Child resources
                            Remove-ManagementGroups -DisplayName $_.DisplayName -Name $_.Name -RootName $RootName
                        }
                        if ($_.Type -eq '/subscriptions') {
                            Write-PSFMessage -Level Verbose -Message "Moving Subscription: $($_.Name)" -FunctionName "AfterAll"
                            # Move Subscription resource to Tenant Root Group
                            New-AzManagementGroupSubscription -GroupId $RootName -SubscriptionId $_.Name -WarningAction SilentlyContinue
                        }
                    }
                }

                Write-PSFMessage -Level Verbose -Message "Removing Management Group: $($DisplayName)" -FunctionName "AfterAll"
                Remove-AzManagementGroup -GroupId $Name -WarningAction SilentlyContinue
            }

        }

        function Remove-ResourceGroups {

            param (
                [Parameter()]
                [string]
                $SubscriptionName,

                [Parameter()]
                [string[]]
                $ResourceGroupNames
            )

            process {
                Write-PSFMessage -Level Verbose -Message "Setting Context: $($SubscriptionName)" -FunctionName "AfterAll"
                Set-AzContext -SubscriptionName $subscriptionName

                $ResourceGroupNames | ForEach-Object {
                    Write-PSFMessage -Level Verbose -Message "Removing Resource Group: $($_)" -FunctionName "AfterAll"
                    Remove-AzResourceGroup -Name $_ -Force
                }
            }

        }

        try {

            #region remove deployed resources
            $managementGroup = Get-AzManagementGroup | Where-Object DisplayName -eq "Test"
            if ($managementGroup) {
                Write-PSFMessage -Level Verbose -Message "Removing Management Group structure" -FunctionName "AfterAll"
                Remove-ManagementGroups -DisplayName "Test" -Name $managementGroup.Name -RootName (Get-AzTenant).TenantId
            }

            $subscription = Get-AzSubscription -SubscriptionId $script:subscriptionId
            Set-AzContext -SubscriptionId $script:subscriptionId
            $roleAssignment = (Get-AzRoleAssignment -ObjectId "023e7c1c-1fa4-4818-bb78-0a9c5e8b0217" | Where-Object { $_.Scope -eq "/subscriptions/$script:subscriptionId" -and $_.RoleDefinitionId -eq "acdd72a7-3385-48ef-bd42-f606fba81ae7" })
            if ($roleAssignment) {
                Write-PSFMessage -Level Verbose -Message "Removing Role Assignment" -FunctionName "AfterAll"
                $roleAssignment | Remove-AzRoleAssignment
            }

            $policyExemption = (Get-AzPolicyExemption -Name "PolicyExemptionTest" -Scope "/subscriptions/$script:subscriptionId" -ErrorAction SilentlyContinue)
            if ($policyExemption) {
                Write-PSFMessage -Level Verbose -Message "Removing Policy Exemption" -FunctionName "AfterAll"
                $null = $policyExemption | Remove-AzPolicyExemption -Force
            }

            $resourceGroup = Get-AzResourceGroup -Name "Application"
            if ($resourceGroup) {
                Write-PSFMessage -Level Verbose -Message "Removing Resource Groups" -FunctionName "AfterAll"
                Remove-ResourceGroups -SubscriptionName $subscription.Name -ResourceGroupNames @($resourceGroup.ResourceGroupName, $script:bicepResourceGroupName)
            }
            #endregion remove deployed resources

            #region remove deployments
            Write-PSFMessage -Level Verbose -Message "Removing Resource Group deployments" -FunctionName "AfterAll"
            $script:ruleCollectionDeployment | Remove-AzResourceGroupDeployment -Confirm:$false
            $script:routeTableDeployment | Remove-AzResourceGroupDeployment -Confirm:$false
            $script:logAnalyticsWorkspaceSavedSearchesDeployment | Remove-AzResourceGroupDeployment -Confirm:$false
            Write-PSFMessage -Level Verbose -Message "Removing Subscription deployments" -FunctionName "AfterAll"
            $script:resourceGroupDeployment | Remove-AzSubscriptionDeployment -Confirm:$false
            $script:roleAssignmentDeployment | Remove-AzSubscriptionDeployment -Confirm:$false
            $script:policyExemptionDeployment | Remove-AzSubscriptionDeployment -Confirm:$false
            Write-PSFMessage -Level Verbose -Message "Removing Management Group deployments" -FunctionName "AfterAll"
            $script:policyAssignmentDeployment | Remove-AzManagementGroupDeployment -Confirm:$false
            $script:managementGroupDeployment | Remove-AzManagementGroupDeployment -Confirm:$false
            #endregion remove deployments
        }
        catch {
            Write-PSFMessage -Level Warning -Message $_ -FunctionName "AfterAll"
        }

    }

}