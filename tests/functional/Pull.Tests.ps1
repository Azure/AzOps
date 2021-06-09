
#
# Pull.Tests.ps1
#
# The tests within this file validate
# that the `Invoke-AzOpsPull`
# function is invoking as expected with
# the correct output data.
#
# This file must be invoked by the Tests.ps1
# file as the Global variable testroot is
# required for invocation.
#

Describe "Pull" {

    BeforeAll {

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        #
        # Invoke the Invoke-AzOpsPull
        # function to generate the scope data which
        # can be tested against to ensure structure
        # is correct and data model hasn't changed.
        #

        Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "BeforeAll"
        try {
            Invoke-AzOpsPull -SkipRole:$true -SkipPolicy:$true -SkipResource:$true
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }

        #
        # The following values match the Reosurce Template
        # which we deploy the platform services with
        # these need to match so that the lookups within
        # the filesystem are aligned.
        #

        $script:managementGroupDeployment = (Get-AzManagementGroupDeployment -ManagementGroupId "$script:tenantId" -Name "AzOps-Tests")
        $script:testManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.testManagementGroup.value)")
        $script:platformManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.platformManagementGroup.value)")
        $script:managementManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.managementManagementGroup.value)")
        $script:subscription = (Get-AzSubscription | Where-Object Id -eq $script:subscriptionId)
        $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq "Application")

        #
        # The following values are discovering the file
        # system paths so that they can be validate against
        # ensuring that the data model hasn't altered.
        # If the model has been changed these tests will
        # need to be updated and a major version increment.
        #

        #region Paths
        $script:generatedRootPath = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $($generatedRootPath)" -FunctionName "BeforeAll"

        $filePaths = (Get-ChildItem -Path $generatedRootPath -Recurse)

        $script:tenantRootGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:tenantId).json")
        $script:tenantRootGroupDirectory = ($script:tenantRootGroupPath).Directory
        $script:tenantRootGroupFile = ($script:tenantRootGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TenantRootGroupPath: $($script:tenantRootGroupFile)" -FunctionName "BeforeAll"

        $script:testManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:testManagementGroup.Name).json")
        $script:testManagementGroupDirectory = ($script:testManagementGroupPath).Directory
        $script:testManagementGroupFile = ($script:testManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TestManagementGroupFile: $($script:testManagementGroupFile)" -FunctionName "BeforeAll"

        $script:platformManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:platformManagementGroup.Name).json")
        $script:platformManagementGroupDirectory = ($script:platformManagementGroupPath).Directory
        $script:platformManagementGroupFile = ($script:platformManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "PlatformManagementGroupFile: $($script:platformManagementGroupFile)" -FunctionName "BeforeAll"

        $script:managementManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:managementManagementGroup.Name).json")
        $script:managementManagementGroupDirectory = ($script:managementManagementGroupPath).Directory
        $script:managementManagementGroupFile = ($script:managementManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ManagementManagementGroupFile: $($script:managementManagementGroupFile)" -FunctionName "BeforeAll"


        $script:subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$($script:subscription.Id).json")
        $script:subscriptionDirectory = ($script:subscriptionPath).Directory
        $script:subscriptionFile = ($script:subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName "BeforeAll"

        $script:resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$($script:resourceGroup.ResourceGroupName).json")
        $script:resourceGroupDirectory = ($script:resourceGroupPath).Directory
        $script:resourceGroupFile = ($script:resourceGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ResourceGroupFile: $($script:resourceGroupFile)" -FunctionName "BeforeAll"
        #endregion Paths

    }

    Context "Test" {

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        #region
        # Scope - Root (./root)
        It "Root directory should exist" {
            Test-Path -Path $script:generatedRootPath | Should -BeTrue
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
        #endregion

    }

    AfterAll { }

}
