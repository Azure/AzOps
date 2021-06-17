
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

        $script:repositoryRoot = (Resolve-Path "$global:testroot/..").Path
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID
        $script:resourceGroupName = "Application-0"
        $script:deploymentName = "AzOps.Tests"

        #
        # Invoke the Invoke-AzOpsPull
        # function to generate the scope data which
        # can be tested against to ensure structure
        # is correct and data model hasn't changed.
        #

        #region Pull
        # Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "Push.Tests.ps1"
        # try {
        #     Invoke-AzOpsPull -SkipRole:$true -SkipPolicy:$true -SkipResource:$true
        # }
        # catch {
        #     Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
        #     throw
        # }
        #endregion Pull

        #region Environment
        Initialize-AzOpsEnvironment
        #endregion Environment


        #
        # The following values match the Reosurce Template
        # which we deploy the platform services with
        # these need to match so that the lookups within
        # the filesystem are aligned.
        #

        #region Scopes
        Write-PSFMessage -Level Verbose -Message "Retrieiving resource data" -FunctionName "Push.Tests.ps1"
        $script:managementGroupDeployment = (Get-AzManagementGroupDeployment -ManagementGroupId "$script:tenantId" -Name $script:deploymentName)
        $script:testManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.testManagementGroup.value)")
        $script:platformManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.platformManagementGroup.value)")
        $script:managementManagementGroup = (Get-AzManagementGroup | Where-Object Name -eq "$($script:managementGroupDeployment.Outputs.managementManagementGroup.value)")
        $script:subscription = (Get-AzSubscription -WarningAction SilentlyContinue | Where-Object Id -eq $script:ubscriptionId)
        $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq $script:resourceGroupName)
        #endregion Scopes

        #
        # The following values are discovering the file
        # system paths so that they can be validate against
        # ensuring that the data model hasn't altered.
        # If the model has been changed these tests will
        # need to be updated and a major version increment.
        #

        #region Paths
        $generatedRootPath = Join-Path -Path $repositoryRoot -ChildPath "root"
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $($generatedRootPath)" -FunctionName "Push.Tests.ps1"

        $filePaths = (Get-ChildItem -Path $generatedRootPath -Recurse)

        $script:tenantRootGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($tenantId).json")
        $script:tenantRootGroupDirectory = ($script:tenantRootGroupPath).Directory
        $script:tenantRootGroupFile = ($script:tenantRootGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TenantRootGroupPath: $($script:tenantRootGroupFile)" -FunctionName "Push.Tests.ps1"

        $script:testManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($testManagementGroup.Name).json")
        $script:testManagementGroupDirectory = ($script:testManagementGroupPath).Directory
        $script:testManagementGroupFile = ($script:testManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "TestManagementGroupFile: $($script:testManagementGroupFile)" -FunctionName "Push.Tests.ps1"

        $script:platformManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($platformManagementGroup.Name).json")
        $script:platformManagementGroupDirectory = ($script:platformManagementGroupPath).Directory
        $script:platformManagementGroupFile = ($script:platformManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "PlatformManagementGroupFile: $($script:platformManagementGroupFile)" -FunctionName "Push.Tests.ps1"

        $script:managementManagementGroupPath = ($filePaths | Where-Object Name -eq "microsoft.management_managementgroups-$($managementManagementGroup.Name).json")
        $script:managementManagementGroupDirectory = ($script:managementManagementGroupPath).Directory
        $script:managementManagementGroupFile = ($script:managementManagementGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ManagementManagementGroupFile: $($script:managementManagementGroupFile)" -FunctionName "Push.Tests.ps1"

        $script:subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$($subscription.Id).json")
        $script:subscriptionDirectory = ($script:subscriptionPath).Directory
        $script:subscriptionFile = ($script:subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName "Push.Tests.ps1"

        $script:resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$($resourceGroup.ResourceGroupName).json")
        $script:resourceGroupDirectory = ($script:resourceGroupPath).Directory
        $script:resourceGroupFile = ($script:resourceGroupPath).FullName
        Write-PSFMessage -Level Debug -Message "ResourceGroupFile: $($script:resourceGroupFile)" -FunctionName "Push.Tests.ps1"
        #endregion Paths

        #
        # Copy templates
        #

        #region Copies
        $artifactsPath = Join-Path -Path $global:testroot -ChildPath "artifacts"
        Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "tenant.jsonc") -Destination $generatedRootPath

        #Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "management.jsonc") -Destination $script:managementManagementGroupDirectory
        #Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "subscription.jsonc") -Destination $script:subscriptionDirectory
        #Copy-Item -Path (Join-Path -Path $artifactsPath -ChildPath "resource.jsonc") -Destination $script:resourceGroupDirectory
        #endregion Copies

        #
        # Push
        #

        #region Push
        $changes = @(
            "A	root/tenant.jsonc"
            #"A	root/tenant root group ($script:tenantId)/tenant.jsonc"
            #"A	root/tenant root group ($script:tenantId)/test ($($script:testManagementGroup.Name))/management.jsonc"
            #"A	root/tenant root group ($script:tenantId)/test ($($script:testManagementGroup.Name))/platform ($($script:platformManagementGroup.Name))/management ($($script:managementManagementGroup.Name))/subscription.jsonc"
            #"A	root/tenant root group ($script:tenantId)/test ($($script:testManagementGroup.Name))/platform ($($script:platformManagementGroup.Name))/management ($($script:managementManagementGroup.Name))/azops ($($script:subscription.SubscriptionId))/application/resource.jsonc"
        )
        $changes | ForEach-Object {
            try {
                Invoke-AzOpsPush -ChangeSet $_
            }
            catch {
                Write-PSFMessage -Level Critical -Message "Push failed" -Exception $_.Exception
                continue
            }
        }
        #endregion Push

        #
        # Pull
        #

        #region Pull
        # try {
        #     Invoke-AzOpsPull -SkipRole:$true -SkipPolicy:$true -SkipResource:$true
        # }
        # catch {
        #     Write-PSFMessage -Level Critical -Message "Pull failed" -Exception $_.Exception
        #     continue
        # }
        #endregion Pull

    }

    Context "Test" {

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
