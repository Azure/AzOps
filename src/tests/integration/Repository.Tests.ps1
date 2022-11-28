
<#
Repository.Tests.ps1
The tests within this file validate that the `Invoke-AzOpsPull` function is invoking as expected with the correct output data.
This file must be invoked by the Pester.ps1 file as the Global variable testroot is required for invocation.
#>

Describe "Repository" {

    BeforeAll {

        Write-PSFMessage -Level Verbose -Message "Initializing test environment" -FunctionName "BeforeAll"

        # Suppress the breaking change warning messages in Azure PowerShell
        Set-Item -Path  Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

        <#
        Script Isolation
        https://github.com/pester/Pester/releases/tag/5.2.0
        #>

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        # Validate that the runtime variables are set as they are used to authenticate the Azure session.

        if ($null -eq $script:tenantId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_TENANT_ID"
            throw
        }
        if ($null -eq $script:subscriptionId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_SUBSCRIPTION_ID"
            throw
        }

        # Ensure PowerShell has an authenticate Azure Context which the tests can run within and generate data as needed

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

        # Deploy the Azure environment based upon prefined resource templates which will generate a matching file system hierachy

        Write-PSFMessage -Level Verbose -Message "Creating repository test environment" -FunctionName "BeforeAll"
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
            New-AzSubscriptionDeployment -Name 'AzOps-Tests-rbacdep' -Location northeurope -TemplateFile "$($global:testRoot)/templates/rbactest.bicep"
            New-AzManagementGroupDeployment @params
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Deployment of repository test failed" -Exception $_.Exception
            throw
        }

        # Wait for Management Group structure consistency

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

        # Ensure that the root directories does not exist before running tests.

        Write-PSFMessage -Level Verbose -Message "Testing for root directory existence" -FunctionName "BeforeAll"
        $generatedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        if (Test-Path -Path $generatedRoot) {
            Write-PSFMessage -Level Verbose -Message "Removing $generatedRoot directory" -FunctionName "BeforeAll"
            Remove-Item -Path $generatedRoot -Recurse
        }
        $partialMgDiscoveryRootgeneratedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "partialmgdiscoveryroot"
        if (Test-Path -Path $partialMgDiscoveryRootgeneratedRoot) {
            Write-PSFMessage -Level Verbose -Message "Removing $partialMgDiscoveryRootgeneratedRoot directory" -FunctionName "BeforeAll"
            Remove-Item -Path $partialMgDiscoveryRootgeneratedRoot -Recurse
        }

        # The following values match the Resource Template which we deploy the platform services with these need to match so that the lookups within the filesystem are aligned.

        try {
            Set-AzContext -SubscriptionId $script:subscriptionId
            $script:locks = Get-AzResourceLock -ResourceGroupName "Lock1-azopsrg"
            $script:policyAssignments = Get-AzPolicyAssignment -Name "TestPolicyAssignment" -Scope "/providers/Microsoft.Management/managementGroups/$($script:managementManagementGroup.Name)"
            $script:policyAssignmentsDep = Get-AzPolicyAssignment -Name "AzOpsDep2 - audit-vm-manageddisks"
            $script:policyAssignmentsDep2 = Get-AzPolicyAssignment -Name "TestPolicyAssignment2" -Scope "/subscriptions/$script:subscriptionId/resourceGroups/Lock2-azopsrg"
            $script:policyDefinitions = Get-AzPolicyDefinition -Name 'TestPolicyDefinition' -ManagementGroupName $($script:testManagementGroup.Name)
            $script:policyDefinitionsDep = Get-AzPolicyDefinition -Name 'TestPolicyDefinitionDep' -ManagementGroupName $($script:testManagementGroup.Name)
            $script:policyDefinitionsDep2 = Get-AzPolicyDefinition -Name 'TestPolicyDefinitionDe2' -ManagementGroupName $($script:testManagementGroup.Name)
            $script:policySetDefinitions = Get-AzPolicySetDefinition -Name 'TestPolicySetDefinition' -ManagementGroupName $($script:testManagementGroup.Name)
            $script:policySetDefinitionsDep = Get-AzPolicySetDefinition -Name 'TestPolicySetDefinitionDep' -ManagementGroupName $($script:testManagementGroup.Name)
            $script:subscription = (Get-AzSubscription | Where-Object Id -eq $script:subscriptionId)
            $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq "App1-azopsrg")
            $script:roleAssignments = (Get-AzRoleAssignment -ObjectId "023e7c1c-1fa4-4818-bb78-0a9c5e8b0217" | Where-Object { $_.Scope -eq "/subscriptions/$script:subscriptionId" -and $_.RoleDefinitionId -eq "acdd72a7-3385-48ef-bd42-f606fba81ae7" })
            $script:policyExemptions = Get-AzPolicyExemption -Name "PolicyExemptionTest" -Scope "/subscriptions/$script:subscriptionId"
            $script:routeTable = (Get-AzResource -Name "RouteTable" -ResourceGroupName $($script:resourceGroup).ResourceGroupName)
            $script:ruleCollectionGroups = (Get-AzResource -ExpandProperties -Name "TestPolicy" -ResourceGroupName $($script:resourceGroup).ResourceGroupName).Properties.ruleCollectionGroups.id.split("/")[-1]
            $script:logAnalyticsWorkspace = (Get-AzResource -Name "thisisalongloganalyticsworkspacename123456789011121314151617181" -ResourceGroupName $($script:resourceGroup).ResourceGroupName)
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Failed to get deployed services" -Exception $_.Exception -FunctionName "BeforeAll"
        }

        # Invoke the Invoke-AzOpsPull function to generate the scope data which can be tested against to ensure structure is correct and data model hasn't changed.

        #region PartialMgDiscoveryRoot Pull
        Set-PSFConfig -FullName AzOps.Core.PartialMgDiscoveryRoot -Value $($script:platformManagementGroup.Name)
        Set-PSFConfig -FullName AzOps.Core.State -Value $partialMgDiscoveryRootgeneratedRoot
        Write-PSFMessage -Level Verbose -Message "Generating folder structure for PartialMgDiscoveryRoot" -FunctionName "BeforeAll"
        try {
            Invoke-AzOpsPull -SkipLock:$true -SkipPim:$true -SkipResourceGroup:$true -SkipPolicy:$true -SkipRole:$true -SkipChildResource:$true -SkipResource:$true
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed for PartialMgDiscoveryRoot" -Exception $_.Exception
            throw
        }
        #endregion PartialMgDiscoveryRoot Pull

        #region GeneratedRoot Pull
        Set-PSFConfig -FullName AzOps.Core.SubscriptionsToIncludeResourceGroups -Value $script:subscriptionId
        Set-PSFConfig -FullName AzOps.Core.PartialMgDiscoveryRoot -Value @()
        Set-PSFConfig -FullName AzOps.Core.State -Value $generatedRoot
        Set-PSFConfig -FullName AzOps.Core.SkipLock -Value $false
        Set-PSFConfig -FullName AzOps.Core.SkipChildResource -Value $false
        Set-PSFConfig -FullName AzOps.Core.DefaultDeploymentRegion -Value "northeurope"
        $deploymentLocationId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)

        Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "BeforeAll"
        try {
            Invoke-AzOpsPull -SkipLock:$false -SkipRole:$false -SkipPolicy:$false -SkipResource:$false
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }
        #endregion GeneratedRoot Pull

        # The following values are discovering the file system paths so that they can be validate against ensuring that the data model behaves as intended.

        #region Paths
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $generatedRoot" -FunctionName "BeforeAll"

        $filePaths = (Get-ChildItem -Path $generatedRoot -Recurse)
        $partialMgDiscoveryRootFilePaths = (Get-ChildItem -Path $partialMgDiscoveryRootgeneratedRoot -Recurse)

        $script:partialMgDiscoveryRootgeneratedRootPath = ($partialMgDiscoveryRootFilePaths | Where-Object Name -eq "microsoft.management_managementgroups-$(($script:platformManagementGroup.Name).toLower()).json")
        $script:partialMgDiscoveryRootgeneratedRootDirectory = ($script:partialMgDiscoveryRootgeneratedRootPath).Directory
        $script:partialMgDiscoveryRootgeneratedRootFile = ($script:partialMgDiscoveryRootgeneratedRootPath).FullName
        Write-PSFMessage -Level Debug -Message "partialMgDiscoveryRootgeneratedRootFile: $($script:partialMgDiscoveryRootgeneratedRootFile)" -FunctionName "BeforeAll"

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

        $script:locksPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_locks-$(($script:locks.Name).toLower()).json")
        $script:locksDirectory = ($script:locksPath).Directory
        $script:locksFile = ($script:locksPath).FullName
        $script:locksDeploymentName = "AzOps-{0}-{1}" -f $($script:locksPath.Name.Replace(".json", '')).Substring(0, 35), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "LockFile: $($script:locksFile)" -FunctionName "BeforeAll"

        $script:policyAssignmentsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policyassignments-$(($script:policyAssignments.Name).toLower()).json")
        $script:policyAssignmentsDirectory = ($script:policyAssignmentsPath).Directory
        $script:policyAssignmentsFile = ($script:policyAssignmentsPath).FullName
        $script:policyAssignmentsDeploymentName = "AzOps-{0}-{1}" -f $($script:policyAssignmentsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyAssignmentsFile: $($script:policyAssignmentsFile)" -FunctionName "BeforeAll"

        $script:policyAssignmentsDepPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policyassignments-$(($script:policyAssignmentsDep.Name).toLower()).json")
        $script:policyAssignmentsDepDirectory = ($script:policyAssignmentsDepPath).Directory
        $script:policyAssignmentsDepFile = ($script:policyAssignmentsDepPath).FullName
        $script:policyAssignmentsDepDeploymentName = "AzOps-{0}-{1}" -f $($script:policyAssignmentsDepPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyAssignmentsFile: $($script:policyAssignmentsDepFile)" -FunctionName "BeforeAll"

        $script:policyAssignmentsDep2Path = ($filePaths | Where-Object Name -eq "microsoft.authorization_policyassignments-$(($script:policyAssignmentsDep2.Name).toLower()).json")
        $script:policyAssignmentsDep2Directory = ($script:policyAssignmentsDep2Path).Directory
        $script:policyAssignmentsDep2File = ($script:policyAssignmentsDep2Path).FullName
        $script:policyAssignmentsDep2DeploymentName = "AzOps-{0}-{1}" -f $($script:policyAssignmentsDep2Path.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyAssignmentsFile: $($script:policyAssignmentsDep2File)" -FunctionName "BeforeAll"

        $script:policyDefinitionsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policydefinitions-$(($script:policyDefinitions.Name).toLower()).parameters.json")
        $script:policyDefinitionsDirectory = ($script:policyDefinitionsPath).Directory
        $script:policyDefinitionsFile = ($script:policyDefinitionsPath).FullName
        $script:policyDefinitionsDeploymentName = "AzOps-{0}-{1}" -f $($script:policyDefinitionsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyDefinitionsFile: $($script:policyDefinitionsFile)" -FunctionName "BeforeAll"

        $script:policyDefinitionsDepPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policydefinitions-$(($script:policyDefinitionsDep.Name).toLower()).parameters.json")
        $script:policyDefinitionsDepDirectory = ($script:policyDefinitionsDepPath).Directory
        $script:policyDefinitionsDepFile = ($script:policyDefinitionsDepPath).FullName
        $script:policyDefinitionsDepDeploymentName = "AzOps-{0}-{1}" -f $($script:policyDefinitionsDepPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyDefinitionsFile: $($script:policyDefinitionsDepFile)" -FunctionName "BeforeAll"

        $script:policyDefinitionsDep2Path = ($filePaths | Where-Object Name -eq "microsoft.authorization_policydefinitions-$(($script:policyDefinitionsDep2.Name).toLower()).parameters.json")
        $script:policyDefinitionsDep2Directory = ($script:policyDefinitionsDep2Path).Directory
        $script:policyDefinitionsDep2File = ($script:policyDefinitionsDep2Path).FullName
        $script:policyDefinitionsDep2DeploymentName = "AzOps-{0}-{1}" -f $($script:policyDefinitionsDep2Path.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicyDefinitionsFile: $($script:policyDefinitionsDep2File)" -FunctionName "BeforeAll"

        $script:policySetDefinitionsDepPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policysetdefinitions-$(($script:policySetDefinitionsDep.Name).toLower()).parameters.json")
        $script:policySetDefinitionsDepDirectory = ($script:policySetDefinitionsDepPath).Directory
        $script:policySetDefinitionsDepFile = ($script:policySetDefinitionsDepPath).FullName
        $script:policySetDefinitionsDepDeploymentName = "AzOps-{0}-{1}" -f $($script:policySetDefinitionsDepPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicySetDefinitionsFile: $($script:policySetDefinitionsDepFile)" -FunctionName "BeforeAll"

        $script:policySetDefinitionsPath = ($filePaths | Where-Object Name -eq "microsoft.authorization_policysetdefinitions-$(($script:policySetDefinitions.Name).toLower()).parameters.json")
        $script:policySetDefinitionsDirectory = ($script:policySetDefinitionsPath).Directory
        $script:policySetDefinitionsFile = ($script:policySetDefinitionsPath).FullName
        $script:policySetDefinitionsDeploymentName = "AzOps-{0}-{1}" -f $($script:policySetDefinitionsPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "PolicySetDefinitionsFile: $($script:policySetDefinitionsFile)" -FunctionName "BeforeAll"

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

        $script:logAnalyticsWorkspaceSavedSearchesPath = ($filePaths | Where-Object Name -eq "microsoft.operationalinsights_workspaces_savedsearches-$(($script:logAnalyticsWorkspace.Name).toLower())_logmanagement(thisisalongloganalyticsworkspacename123456789011121314151617181)_generalstalecomputers.json")
        $script:logAnalyticsWorkspaceSavedSearchesDirectory = ($script:logAnalyticsWorkspaceSavedSearchesPath).Directory
        $script:logAnalyticsWorkspaceSavedSearchesFile = ($script:logAnalyticsWorkspaceSavedSearchesPath).FullName
        Write-PSFMessage -Level Debug -Message "logAnalyticsWorkspaceSavedSearchesFile: $($script:logAnalyticsWorkspaceSavedSearchesFile)" -FunctionName "BeforeAll"

        $script:bicepTemplatePath = Get-ChildItem -Path "$($global:testRoot)/templates/biceptest*" | Copy-Item -Destination $script:subscriptionDirectory -PassThru -Force
        $script:bicepDeploymentName = "AzOps-{0}-{1}" -f $($script:bicepTemplatePath[0].Name.Replace(".bicep", '')), $deploymentLocationId
        $script:bicepResourceGroupName = ((Get-Content -Path ($Script:bicepTemplatePath.FullName[1])) | ConvertFrom-Json).parameters.resourceGroupName.value

        $script:pushmgmttest1idManagementGroupTemplatePath = Get-Item "$($global:testroot)/templates/pushmgmttest1displayname (pushmgmttest1id)" | Copy-Item -Destination $script:testManagementGroupDirectory -Recurse -PassThru -Force
        $script:pushmgmttest1idManagementGroupDeploymentName = "AzOps-{0}-{1}" -f "$($script:pushmgmttest1idManagementGroupTemplatePath[1].Name.Replace(".json", ''))", $deploymentLocationId
        $script:pushmgmttest1idName = ((Get-Content -Path ($script:pushmgmttest1idManagementGroupTemplatePath.FullName[1])) | ConvertFrom-Json).resources.name[0]

        $script:pushmgmttest2idManagementGroupTemplatePath = Get-Item "$($global:testroot)/templates/pushmgmttest1displayname (pushmgmttest1id)" | Copy-Item -Destination $script:platformManagementGroupDirectory -Recurse -PassThru -Force
        #endregion Paths

        #Test push based on pulled resources
        $changeSet = @(
            "A`t$script:testManagementGroupFile",
            "A`t$script:policyAssignmentsFile",
            "A`t$script:policyDefinitionsFile",
            "A`t$script:policySetDefinitionsFile",
            "A`t$script:policyExemptionsFile",
            "A`t$script:roleAssignmentsFile",
            "A`t$script:resourceGroupFile",
            "A`t$script:routeTableFile",
            "A`t$script:ruleCollectionGroupsFile",
            "A`t$script:locksFile",
            "A`t$($script:bicepTemplatePath.FullName[0])",
            "A`t$($script:pushmgmttest1idManagementGroupTemplatePath.FullName[1])"
        )
        Invoke-AzOpsPush -ChangeSet $changeSet

        #Test deletion of supported resources
        $changeSet = @(
            "D`t$script:policyAssignmentsFile",
            "D`t$script:policyDefinitionsFile",
            "D`t$script:policySetDefinitionsFile",
            "D`t$script:policyExemptionsFile",
            "D`t$script:roleAssignmentsFile",
            "D`t$script:locksFile"
        )
        $DeleteSetContents += (Get-Content $Script:policyAssignmentsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:policyDefinitionsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:policySetDefinitionsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:policyExemptionsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:roleAssignmentsFile)
        $DeleteSetContents += '-- '
        $DeleteSetContents += (Get-Content $Script:locksFile)
        Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents
    }

    Context "Test" {

        #region
        # Scope - Root (./root)
        It "Root directory should exist" {
            Test-Path -Path $generatedRoot | Should -BeTrue
        }
        #endregion

        #region Scope - Management Group (./partialmgdiscoveryroot/platform/)
        It "Partialmgdiscoveryroot directory should exist" {
            Test-Path -Path $partialMgDiscoveryRootgeneratedRoot | Should -BeTrue
        }
        It "Partialmgdiscoveryroot directory count should be: 5, (platform, management, microsoft azops, identity and connectivity)" {
            $partialMgDiscoveryRootFilePaths.directory.count | Should -BeExactly "5"
        }
        It "Partialmgdiscoveryroot Management Group directory management should exist" {
            Test-Path -Path $script:partialMgDiscoveryRootgeneratedRootDirectory | Should -BeTrue
        }
        It "Partialmgdiscoveryroot Management Group file management should exist" {
            Test-Path -Path $script:partialMgDiscoveryRootgeneratedRootFile | Should -BeTrue
        }
        It "Partialmgdiscoveryroot Management Group management resource type should exist" {
            $fileContents = Get-Content -Path $script:partialMgDiscoveryRootgeneratedRootFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Partialmgdiscoveryroot Management Group management resource name should exist" {
            $fileContents = Get-Content -Path $script:partialMgDiscoveryRootgeneratedRootFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Partialmgdiscoveryroot Management Group management resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:partialMgDiscoveryRootgeneratedRootFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Partialmgdiscoveryroot Management Group management resource type should match" {
            $fileContents = Get-Content -Path $script:partialMgDiscoveryRootgeneratedRootFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        }
        It "Partialmgdiscoveryroot Management Group management scope property should match" {
            $fileContents = Get-Content -Path $script:partialMgDiscoveryRootgeneratedRootFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].scope | Should -Be "/"
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

        #region Scope = Locks (./root/tenant root group/test/platform/management/subscription-0/Lock1-azopsrg/Locks/Lock)
        It "Locks directory should exist" {
            Test-Path -Path $script:locksDirectory | Should -BeTrue
        }
        It "Locks file should exist" {
            Test-Path -Path $script:locksFile | Should -BeTrue
        }
        It "Locks resource type should exist" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Locks resource name should exist" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Locks resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Locks resource properties should exist" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Locks resource type should match" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Authorization/locks"
        }
        It "Locks level property should match" {
            $fileContents = Get-Content -Path $script:locksFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties.level | Should -Be "CanNotDelete"
        }
        It "Locks deployment should be successful" {
            $script:locksDeployment = Get-AzResourceGroupDeployment -Name $script:locksDeploymentName -ResourceGroupName $script:locks.ResourceGroupName
            $script:locksDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "Locks deletion should be successful" {
            $locksDeletion = Get-AzResourceLock -ResourceGroupName $script:locks.ResourceGroupName -ErrorAction SilentlyContinue
            $locksDeletion | Should -Be $Null
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

        #region Scope = PolicyDefinition (./root/tenant root group/test/PolicyDefinition)
        It "Policy Definitions directory should exist" {
            Test-Path -Path $script:policyDefinitionsDirectory | Should -BeTrue
        }
        It "Policy Definitions file should exist" {
            Test-Path -Path $script:policyDefinitionsFile | Should -BeTrue
        }
        It "Policy Definitions resource type should exist" {
            $fileContents = Get-Content -Path $script:policyDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.ResourceType | Should -BeTrue
        }
        It "Policy Definitions resource name should exist" {
            $fileContents = Get-Content -Path $script:policyDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.name | Should -BeTrue
        }
        It "Policy Definitions resource properties should exist" {
            $fileContents = Get-Content -Path $script:policyDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.properties | Should -BeTrue
        }
        It "Policy Definitions resource type should match" {
            $fileContents = Get-Content -Path $script:policyDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.ResourceType | Should -Be "Microsoft.Authorization/policyDefinitions"
        }
        It "Policy Definitions deployment should be successful" {
            $script:policyDefinitionDeployment = Get-AzManagementGroupDeployment -ManagementGroupId $script:testManagementGroup.Name -Name $script:policyDefinitionsDeploymentName
            $policyDefinitionDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "Policy Definitions deletion should be successful" {
            $policyDefinitionDeletion = Get-AzPolicyDefinition -Id $script:policyDefinitions.PolicyDefinitionId -ErrorAction SilentlyContinue
            if ($policyDefinitionDeletion) {
                $policyDefinitionDeletion.PolicyDefinitionId[0] | Should -Not -Be $script:policyDefinitions.PolicyDefinitionId
            }
            else {
                $policyDefinitionDeletion | Should -Be $Null
            }
        }
        #endregion

        #region Scope = PolicySetDefinition (./root/tenant root group/test/PolicySetDefinition)
        It "PolicySetDefinitions directory should exist" {
            Test-Path -Path $script:policySetDefinitionsDirectory | Should -BeTrue
        }
        It "PolicySetDefinitions file should exist" {
            Test-Path -Path $script:policySetDefinitionsFile | Should -BeTrue
        }
        It "PolicySetDefinitions resource type should exist" {
            $fileContents = Get-Content -Path $script:policySetDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.ResourceType | Should -BeTrue
        }
        It "PolicySetDefinitions resource name should exist" {
            $fileContents = Get-Content -Path $script:policySetDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.name | Should -BeTrue
        }
        It "PolicySetDefinitions resource properties should exist" {
            $fileContents = Get-Content -Path $script:policySetDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.properties | Should -BeTrue
        }
        It "PolicySetDefinitions resource type should match" {
            $fileContents = Get-Content -Path $script:policySetDefinitionsFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.parameters.input.value.ResourceType | Should -Be "Microsoft.Authorization/policySetDefinitions"
        }
        It "PolicySetDefinitions deployment should be successful" {
            $script:policySetDefinitionDeployment = Get-AzManagementGroupDeployment -ManagementGroupId $script:testManagementGroup.Name -Name $script:policySetDefinitionsDeploymentName
            $policySetDefinitionDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "PolicySetDefinitions deletion should be successful" {
            $policySetDefinitionDeletion = Get-AzPolicySetDefinition -Id $script:policySetDefinitions.PolicySetDefinitionId -ErrorAction SilentlyContinue
            if ($policySetDefinitionDeletion) {
                $policySetDefinitionDeletion.PolicySetDefinitionId[0] | Should -Not -Be $script:policySetDefinitions.PolicySetDefinitionId
            }
            else {
                $policySetDefinitionDeletion | Should -Be $Null
            }
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

        #region Scope - Resource Group (./root/tenant root group/test/platform/management/subscription-0/App1-azopsrg)
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

        #region Scope - Route Table (./root/tenant root group/test/platform/management/subscription-0/App1-azopsrg/routetable)
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
            $script:routeTableDeployment = Get-AzResourceGroupDeployment -ResourceGroupName 'App1-azopsrg' -Name $script:routeTableDeploymentName
            $routeTableDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Scope - ruleCollectionGroup (./root/tenant root group/test/platform/management/subscription-0/App1-azopsrg/testpolicy/testgroup)
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
            $script:ruleCollectionDeployment = Get-AzResourceGroupDeployment -ResourceGroupName 'App1-azopsrg' -Name $script:ruleCollectionDeploymentName
            $ruleCollectionDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion

        #region Scope - logAnalyticsWorkspaceSavedSearchesPath (./root/tenant root group/test/platform/management/subscription-0/App1-azopsrg/thisisalongloganalyticsworkspacename123456789011121314151617181)
        It "LogAnalyticsWorkspaceSavedSearches directory should exist" {
            Test-Path -Path $script:logAnalyticsWorkspaceSavedSearchesDirectory | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches file should exist" {
            Test-Path -Path $script:logAnalyticsWorkspaceSavedSearchesFile | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches filename should not have invalid character '|'" {
            $script:logAnalyticsWorkspaceSavedSearchesFile | Should -Not -BeLike "*|*"
        }
        It "LogAnalyticsWorkspaceSavedSearches resource type should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource name should exist" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "LogAnalyticsWorkspaceSavedSearches resource name should have invalid character '|'" {
            $fileContents = Get-Content -Path $script:logAnalyticsWorkspaceSavedSearchesFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeLike "*|*"
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

        #region Deploy Management Group using folder structure and file
        It "ManagementGroup deployment using folder structure and file should be successful" {
            $script:pushmgmttest1Deployment = Get-AzTenantDeployment -Name $script:pushmgmttest1idManagementGroupDeploymentName
            $pushmgmttest1Deployment.ProvisioningState | Should -Be "Succeeded"
        }
        It "ManagementGroup deployed using folder structure and file should exist" {
            $script:pushmgmttest1Mg = Get-AzManagementGroup -GroupName $script:pushmgmttest1idName
            $pushmgmttest1Mg.Name | Should -Be $script:pushmgmttest1idName
        }
        It "ManagementGroup deployed using folder structure and file at folder scope not matching content parent should fail" {
            $changeSet = @(
                "A`t$($script:pushmgmttest2idManagementGroupTemplatePath.FullName[1])"
            )
            {Invoke-AzOpsPush -ChangeSet $changeSet -WhatIf:$true} | Should -Throw
        }
        #endregion

        #region Scope - Policy DeletionDependency
        It "Deletion of policyDefinitionsFile with assignment dependency should fail" {
            $changeSet = @(
                "D`t$script:policyDefinitionsDepFile"
            )
            $DeleteSetContents = (Get-Content $Script:policyDefinitionsDepFile)
            {Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents -WhatIf:$true} | Should -Throw
        }
        It "Deletion of policySetDefinitionsFile with assignment dependency should fail" {
            $changeSet = @(
                "D`t$script:policySetDefinitionsDepFile"
            )
            $DeleteSetContents = (Get-Content $Script:policySetDefinitionsDepFile)
            {Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents -WhatIf:$true} | Should -Throw
        }
        It "Deletion of policyDefinitionsFile with setDefinition dependency should fail" {
            $changeSet = @(
                "D`t$script:policyDefinitionsDep2File"
            )
            $DeleteSetContents = (Get-Content $script:policyDefinitionsDep2File)
            {Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents -WhatIf:$true} | Should -Throw
        }
        It "Deletion of policyAssignmentFile with role assignment dependency should fail" {
            $changeSet = @(
                "D`t$script:policyAssignmentsDepFile"
            )
            $DeleteSetContents = (Get-Content $script:policyAssignmentsDepFile)
            {Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents -WhatIf:$true} | Should -Throw
        }
        It "Deletion of policyAssignmentFile with lock dependency should fail" {
            $changeSet = @(
                "D`t$script:policyAssignmentsDep2File"
            )
            $DeleteSetContents = (Get-Content $script:policyAssignmentsDep2File)
            {Invoke-AzOpsPush -ChangeSet $changeSet -DeleteSetContents $deleteSetContents -WhatIf:$true} | Should -Throw
        }
        #endregion
    }

    AfterAll {

    }

}