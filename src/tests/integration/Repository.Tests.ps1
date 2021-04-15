$script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
$script:tenantId = $env:ARM_TENANT_ID

#
# Repository.Tests.ps1
#
# The tests within this file validate
# that the `Initialize-AzOpsRepository`
# function is invoking as expected with
# the correct output data.
#
# This file must be invoked by the Tests.ps1
# file as the Global variable testroot is
# required for invocation.
#

Describe "Repository" {

    BeforeAll {

        Write-PSFMessage -Level Important -Message "Initializing test environment" -FunctionName "BeforeAll"

        #
        # Ensure PowerShell has an authenticate
        # Azure Context which the tests can
        # run within and generate data as needed
        #

        Write-PSFMessage -Level Important -Message "Validationg Azure context" -FunctionName "BeforeAll"
        $tenant = (Get-AzContext -ListAvailable -ErrorAction SilentlyContinue).Tenant.Id
        if ($tenant -notcontains $tenantId) {
            Write-PSFMessage -Level Important -Message "Authenticating Azure session" -FunctionName "BeforeAll"
            if ($env:USER -eq "vsts") {
                # Pipeline
                $credential = New-Object PSCredential -ArgumentList $(ARM_CLIENT_ID), (ConvertTo-SecureString -String $(ARM_CLIENT_SECRET) -AsPlainText -Force)
                Connect-AzAccount -TenantId $(ARM_TENANT_ID) -ServicePrincipal -Credential $credential -SubscriptionId $(ARM_SUBSCRIPTION_ID) -ErrorAction Stop
            }
            else {
                # Local
                Connect-AzAccount -UseDeviceAuthentication
            }
        }

        #
        # Deploy the Azure environment
        # based upon prefined resource templates
        # which will generate a matching
        # file system hierachy
        #

        Write-PSFMessage -Level Important -Message "Creating Management Group structure" -FunctionName "BeforeAll"
        $templateFile = Join-Path -Path $global:testroot -ChildPath "templates/azuredeploy.jsonc"
        New-AzTenantDeployment -Name "AzOps-Tests" -TemplateFile $templateFile -Location "uksouth"

        #
        # Ensure that the root directory
        # does not exist before running
        # tests.
        #

        Write-PSFMessage -Level Important -Message "Testing for root directory existence" -FunctionName "BeforeAll"
        $generatedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        if (Test-Path -Path $generatedRoot) {
            Write-PSFMessage -Level Important -Message "Removing root directory" -FunctionName "BeforeAll"
            Remove-Item -Path $generatedRoot -Recurse
        }

        #
        # Invoke the Initialize-AzOpsRepository
        # function to generate the scope data which
        # can be tested against to ensure structure
        # is correct.
        #

        Write-PSFMessage -Level Important -Message "Generating folder structure" -FunctionName "BeforeAll"
        Initialize-AzOpsRepository -SkipRole:$true -SkipPolicy:$true

    }

    Context "Test" {

        #region Paths
        $script:generatedRootPath = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $($generatedRootPath)" -FunctionName Context

        $filePaths = (Get-ChildItem -Path $generatedRootPath -Recurse)

        $script:tenantRootGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($tenantId).json")
        $script:tenantRootGroupDirectory = ($script:tenantRootGroupPath).Directory
        $script:tenantRootGroupFile = ($script:tenantRootGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TenantRootGroupPath: $($script:tenantRootGroupFile)" -FunctionName Context

        $script:testManagementGroup = (Get-AzManagementGroup | Where-Object DisplayName -eq "Test")
        $script:testManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:testManagementGroup.Name).json")
        $script:testManagementGroupDirectory = ($script:testManagementGroupPath).Directory
        $script:testManagementGroupFile = ($script:testManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TestManagementGroupFile: $($script:testManagementGroupFile)" -FunctionName Context

        $script:platformManagementGroup = (Get-AzManagementGroup | Where-Object DisplayName -eq "Platform")
        $script:platformManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:platformManagementGroup.Name).json")
        $script:platformManagementGroupDirectory = ($script:platformManagementGroupPath).Directory
        $script:platformManagementGroupFile = ($script:platformManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "PlatformManagementGroupFile: $($script:platformManagementGroupFile)" -FunctionName Context

        $script:managementManagementGroup = (Get-AzManagementGroup | Where-Object DisplayName -eq "Management")
        $script:managementManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($script:managementManagementGroup.Name).json")
        $script:managementManagementGroupDirectory = ($script:managementManagementGroupPath).Directory
        $script:managementManagementGroupFile = ($script:managementManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ManagementManagementGroupFile: $($script:managementManagementGroupFile)" -FunctionName Context

        $script:subscription = (Get-AzSubscription | Where-Object Name -eq "Subscription-0")
        $script:subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$($script:subscription.Id).json")
        $script:subscriptionDirectory = ($script:subscriptionPath).Directory
        $script:subscriptionFile = ($script:subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName Context

        $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq "Application")
        $script:resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$($script:resourceGroup.ResourceGroupName).json")
        $script:resourceGroupDirectory = ($script:resourceGroupPath).Directory
        $script:resourceGroupFile = ($script:resourceGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName Context
        #endregion Paths

        # Test Cases

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
            Test-Path -Path $resourceGroupDirectory | Should -BeTrue
        }
        It "Resource Group file should exist" {
            Test-Path -Path $resourceGroupFile | Should -BeTrue
        }
        It "Resource Group resource type should match" {
            $fileContents = Get-Content -Path $resourceGroupFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Resources/resourceGroups"
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
                            Write-PSFMessage -Level Important -Message "Moving Subscription $($_.Name)" -FunctionName "AfterAll"
                            # Move Subscription resource to Tenant Root Group
                            New-AzManagementGroupSubscription -GroupId $RootName -SubscriptionId $_.Name -WarningAction SilentlyContinue
                        }
                    }
                }

                Write-PSFMessage -Level Important -Message "Removing Management Group $($DisplayName)" -FunctionName "AfterAll"
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
                Write-PSFMessage -Level Important -Message "Setting context to Subscription $($SubscriptionName)" -FunctionName "AfterAll"
                Set-AzContext -SubscriptionName $subscriptionName

                $ResourceGroupNames | ForEach-Object {
                    Write-PSFMessage -Level Important -Message "Removing Resource Group $($ResourceGroupName)" -FunctionName "AfterAll"
                    Remove-AzResourceGroup -Name $_ -Force
                }
            }

        }

        Write-PSFMessage -Level Important -Message "Removing Management Group structure" -FunctionName "AfterAll"
        $managementGroup = Get-AzManagementGroup | Where-Object DisplayName -eq "Test"
        Remove-ManagementGroups -DisplayName "Test" -Name $managementGroup.Name -RootName (Get-AzTenant).TenantId

        Write-PSFMessage -Level Important -Message "Removing Resource Groups" -FunctionName "AfterAll"
        Remove-ResourceGroups -SubscriptionName "Subscription-0" -ResourceGroupNames @("Application")

    }
}