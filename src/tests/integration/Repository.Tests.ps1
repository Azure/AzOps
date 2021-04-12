$repositoryRoot = (Resolve-Path "$global:testroot/../..").Path

$script:rootPath = Join-Path -Path $repositoryRoot -ChildPath "root"

# TODO: Inject with environment variables
$script:tenantId = "e42bc18f-3ab8-4bca-b643-24d2e0780b07"
$script:managementGroupDisplayName = "development"
$script:managementGroupName = "61a389c4-561c-441e-8ff8-30abb9cf64f8"
$script:subscriptionName = "subscription-0"
$script:subscriptionId = "1e045925-5a73-42d1-ae33-b3803bfb8ea9"
$script:resourceGroupName = "application-0"

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

        Write-PSFMessage -Level Important -Message "Initializing test environment"

        #
        # Deploy the Azure environment
        # based upon prefined resource templates
        # which will generate a matching
        # file system hierachy
        #

        #
        # Ensure that the root directory
        # does not exist before running
        # tests.
        #

        # TODO: Review this implementation

        Write-PSFMessage -Level Important -Message "Testing for root directory existence"
        if (Test-Path -Path $script:rootPath) {
            Write-PSFMessage -Level Important -Message "Removing root directory"
            Remove-Item -Path $script:rootPath -Recurse
        }

        #
        # Ensure PowerShell has an authenticate
        # Azure Context which the tests can
        # run within and generate data as needed
        #

        # ?: Should this check for Management Groups
        if ((Get-AzContext -ListAvailable).Tenant.Id -notcontains $script:tenantId) {
            Write-PSFMessage -Level Important -Message "Unauthenticated PowerShell session"
            # TODO: Replace with Service Principal
            Connect-AzAccount -UseDeviceAuthentication
        }

        #
        # Invoke the Initialize-AzOpsRepository
        # function to generate the scope data which
        # can be tested against to ensure structure
        # is correct.
        #

        Write-PSFMessage -Level Important -Message "Generating test folder structure"
        Initialize-AzOpsRepository -SkipRole:$true -SkipPolicy:$true

    }

    Context "Test" {

        #region Paths
        $script:tenantRootPath = (Join-Path -Path $script:rootPath -ChildPath "tenant root group ($script:tenantId)")
        $script:managementGroupPath = (Join-Path -Path $script:tenantRootPath -ChildPath "$($script:managementGroupDisplayName) ($($script:managementGroupName))")
        $script:subscriptionPath = (Join-Path -Path $script:managementGroupPath -ChildPath "$($script:subscriptionName) ($($script:subscriptionId))")
        $script:resourceGroupPath = (Join-Path -Path $script:subscriptionPath -ChildPath "$($script:resourceGroupName)")
        #endregion Paths

        # Test Cases

        #region
        # Scope: Root (./root)
        It "Root directory should exist" {
            Test-Path -Path $script:rootPath | Should -BeTrue
        }
        #endregion

        #region
        # Scope: Tenant Root Group (./root/tenant root group)
        $filePath = (Join-Path -Path $script:tenantRootPath -ChildPath "microsoft.management_managementgroups-$($script:tenantId).parameters.json")
        It "Tenant Root Group directory should exist" {
            Test-Path -Path $script:tenantRootPath | Should -BeTrue
        }
        It "Tenant Root Group file should exist" {
            Test-Path -Path $filePath | Should -BeTrue
        }
        # It "Tenant Root Group resource type should match" {
        #     $fileContents = Get-Content -Path $filePath -Raw | ConvertFrom-Json -Depth 5
        #     $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        # }
        # It "Tenant Root Group scope property should match" {
        #     $fileContents = Get-Content -Path $filePath -Raw | ConvertFrom-Json -Depth 5
        #     $fileContents.resources[0].scope | Should -Be "/"
        # }
        #endregion

        #region
        # Scope: Management Group (./root/tenant root group/development)
        $script:filePath = (Join-Path -Path $script:managementGroupPath -ChildPath "microsoft.management_managementgroups-$($script:managementGroupName).parameters.json")
        It "Management Group directory should exist" {
            Test-Path -Path $script:managementGroupPath | Should -BeTrue
        }
        It "Management Group file should exist" {
            Test-Path -Path $script:filePath | Should -BeTrue
        }
        # It "Management Group resource type should match" {
        #     $fileContents = Get-Content -Path $filePath -Raw | ConvertFrom-Json -Depth 5
        #     $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups"
        # }
        # It "Management Group scope property should match" {
        #     $fileContents = Get-Content -Path $filePath -Raw | ConvertFrom-Json -Depth 5
        #     $fileContents.resources[0].scope | Should -Be "/"
        # }
        #endregion

        #region
        # Scope: Subscription (./root/tenant root group/development/subscription-0)
        $script:filePath = (Join-Path -Path $script:subscriptionPath -ChildPath "microsoft.subscription_subscriptions-$($script:subscriptionId).json")
        It "Subscription directory should exist" {
            Test-Path -Path $script:subscriptionPath | Should -BeTrue
        }
        It "Subscription file should exist" {
            $script:filePath = (Join-Path -Path $script:subscriptionPath -ChildPath "microsoft.subscription_subscriptions-$($script:subscriptionId).json")
            Test-Path -Path $script:filePath | Should -BeTrue
        }
        It "Subscription resource type should match" {
            $fileContents = Get-Content -Path $script:filePath -Raw | ConvertFrom-Json -Depth 5
            $fileContents.resources[0].type | Should -Be "Microsoft.Management/managementGroups/subscriptions"
        }
        It "Subscription scope should match" {
            $fileContents = Get-Content -Path $script:filePath -Raw | ConvertFrom-Json -Depth 5
            $fileContents.resources[0].scope | Should -Be "/"
        }
        #endregion

        #region
        # Scope: Resource Group (./root/tenant root group/development/subscription-0/application-0)
        $script:filePath = (Join-Path -Path $script:resourceGroupPath -ChildPath "microsoft.resources_resourcegroups-$($script:resourceGroupName).json")
        It "Resource Group directory should exist" {
            Test-Path -Path $script:resourceGroupPath | Should -BeTrue
        }
        It "Resource Group file should exist" {
            Test-Path -Path $script:filePath | Should -BeTrue
        }
        It "Resource Group resource type should match" {
            $fileContents = Get-Content -Path $script:filePath -Raw | ConvertFrom-Json -Depth 5
            $fileContents.resources[0].type | Should -Be "Microsoft.Resources/resourceGroups"
        }
        #endregion

    }
}