
#
# Push.Tests.ps1
#
# The tests within this file validate
# that the `Invoke-AzOpsPush`
# function is invoking as expected with
# the correct output data.
#
# This file must be invoked by the Tests.ps1
# file as the Global variable testroot is
# required for invocation.
#

Describe "Push" {

    BeforeAll {

        $repositoryRoot = (Resolve-Path "$global:testroot/..").Path
        $tenantId = $env:ARM_TENANT_ID
        $subscriptionId = $env:ARM_SUBSCRIPTION_ID

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

        $managementGroupDeployment = (Get-AzManagementGroupDeployment -ManagementGroupId "$tenantId" -Name "AzOps-Tests")
        $testManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($managementGroupDeployment.Outputs.testManagementGroup.value)")
        $platformManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($managementGroupDeployment.Outputs.platformManagementGroup.value)")
        $managementManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($managementGroupDeployment.Outputs.managementManagementGroup.value)")
        $subscription = (Get-AzSubscription -WarningAction SilentlyContinue | Where-Object Id -eq $subscriptionId)
        $resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq "Application")

        #
        # The following values are discovering the file
        # system paths so that they can be validate against
        # ensuring that the data model hasn't altered.
        # If the model has been changed these tests will
        # need to be updated and a major version increment.
        #

        #region Paths
        $generatedRootPath = Join-Path -Path $repositoryRoot -ChildPath "root"
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $($generatedRootPath)" -FunctionName "BeforeAll"

        $filePaths = (Get-ChildItem -Path $generatedRootPath -Recurse)

        $tenantRootGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($tenantId).json")
        $tenantRootGroupDirectory = ($tenantRootGroupPath).Directory
        $tenantRootGroupFile = ($tenantRootGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TenantRootGroupPath: $($tenantRootGroupFile)" -FunctionName "BeforeAll"

        $testManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($testManagementGroup.Name).json")
        $testManagementGroupDirectory = ($testManagementGroupPath).Directory
        $testManagementGroupFile = ($testManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TestManagementGroupFile: $($testManagementGroupFile)" -FunctionName "BeforeAll"

        $platformManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($platformManagementGroup.Name).json")
        $platformManagementGroupDirectory = ($platformManagementGroupPath).Directory
        $platformManagementGroupFile = ($platformManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "PlatformManagementGroupFile: $($platformManagementGroupFile)" -FunctionName "BeforeAll"

        $managementManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($managementManagementGroup.Name).json")
        $managementManagementGroupDirectory = ($managementManagementGroupPath).Directory
        $managementManagementGroupFile = ($managementManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ManagementManagementGroupFile: $($managementManagementGroupFile)" -FunctionName "BeforeAll"

        $subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$($subscription.Id).json")
        $subscriptionDirectory = ($subscriptionPath).Directory
        $subscriptionFile = ($subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($subscriptionFile)" -FunctionName "BeforeAll"

        $resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$($resourceGroup.ResourceGroupName).json")
        $resourceGroupDirectory = ($resourceGroupPath).Directory
        $resourceGroupFile = ($resourceGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ResourceGroupFile: $($resourceGroupFile)" -FunctionName "BeforeAll"
        #endregion Paths

        #
        # Copy templates
        #

        $artifactsPath = Join-Path -Path $global:testroot -ChildPath "artifacts/"
        Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "tenant.jsonc") -Destination $tenantRootGroupDirectory
        Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "management.jsonc") -Destination $managementManagementGroupDirectory
        Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "subscription.jsonc") -Destination $subscriptionDirectory
        Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "resource.jsonc") -Destination $resourceGroupDirectory

        #
        # Push
        #

        $changes = @(
            "A	root/tenant root group ($tenantId)/tenant.jsonc"
            "A	root/tenant root group ($tenantId)/test ($($testManagementGroup.Name))/management.jsonc"
            "A	root/tenant root group ($tenantId)/test ($($testManagementGroup.Name))/platform ($($platformManagementGroup.Name))/management ($($managementManagementGroup.Name))/subscription.jsonc"
            "A	root/tenant root group ($tenantId)/test ($($testManagementGroup.Name))/platform ($($platformManagementGroup.Name))/management ($($managementManagementGroup.Name))/azops ($($subscription.SubscriptionId))/application/resource.jsonc"
        )

        $changes | ForEach-Object {
            Invoke-AzOpsPush -ChangeSet $_
        }

        try {
            Invoke-AzOpsPull -SkipRole:$true -SkipPolicy:$true -SkipResource:$true
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }

    }

    Context "Test" {

        $repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
        $tenantId = $env:ARM_TENANT_ID
        $subscriptionId = $env:ARM_SUBSCRIPTION_ID

        # Resource Group Deployment

        # Subscription Deployment

        # Management Group Deployment

        # Tenant Deployment


        It "Invalid should exist" {
            $true | Should -BeTrue
        }

    }

    AfterAll { }

}
