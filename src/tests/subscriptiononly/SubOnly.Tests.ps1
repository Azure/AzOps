<#
SubOnly.Tests.ps1
The tests within this file validate that the `Invoke-AzOpsPull` function is invoking as expected with the correct output data.
This file must be invoked by the Pester.ps1 file as the Global variable testroot is required for invocation.
#>

Describe "SubscriptionOnly" {

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
        try {
            $rg = New-AzSubscriptionDeployment -Name 'AzOps-Tests-SubOnly-RG' -Location 'northeurope'  -TemplateParameterFile "$($global:testRoot)/templates/rgsubonlydeploy.parameters.json" -TemplateFile "$($global:testRoot)/templates/rgsubonlydeploy.bicep"
            $sta = New-AzResourceGroupDeployment -Name 'AzOps-Tests-SubOnly-Sta' -ResourceGroupName $rg.Parameters.resourceGroupName.Value -TemplateFile "$($global:testRoot)/templates/stasubonlydeploy.bicep"
            # Pause for resource consistency
            Start-Sleep -Seconds 120
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Deployment of repository test failed" -Exception $_.Exception
            throw
        }

        # Ensure that the root directories does not exist before running tests.

        Write-PSFMessage -Level Verbose -Message "Testing for root directory existence" -FunctionName "BeforeAll"
        $generatedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "root"
        if (Test-Path -Path $generatedRoot) {
            Write-PSFMessage -Level Verbose -Message "Removing $generatedRoot directory" -FunctionName "BeforeAll"
            Remove-Item -Path $generatedRoot -Recurse
        }

        # The following values match the Resource Template which we deploy the platform services with these need to match so that the lookups within the filesystem are aligned.

        try {
            Set-AzContext -SubscriptionId $script:subscriptionId
            $script:subscription = (Get-AzSubscription | Where-Object Id -eq $script:subscriptionId)
            $script:resourceGroup = (Get-AzResourceGroup | Where-Object ResourceGroupName -eq $sta.ResourceGroupName)
            $script:storageAccount = Get-AzResource -Name $sta.Parameters.staName.Value -ResourceGroupName $script:resourceGroup.ResourceGroupName
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Failed to get deployed services" -Exception $_.Exception -FunctionName "BeforeAll"
        }

        # Invoke the Invoke-AzOpsPull function to generate the scope data which can be tested against to ensure structure is correct and data model hasn't changed.

        #region GeneratedRoot Pull
        Set-PSFConfig -FullName AzOps.Core.State -Value $generatedRoot
        Set-PSFConfig -FullName AzOps.Core.DefaultDeploymentRegion -Value "northeurope"
        $deploymentLocationId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)

        Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "BeforeAll"
        try {
            Initialize-AzOpsEnvironment
            Invoke-AzOpsPull -SkipRole:$false -SkipPolicy:$false -SkipResource:$false
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }
        #endregion GeneratedRoot Pull

        # The following values are discovering the file system paths, ensuring that the model behaves as intended.

        #region Paths
        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $generatedRoot" -FunctionName "BeforeAll"

        $filePaths = (Get-ChildItem -Path $generatedRoot -Recurse)

        $script:subscriptionPath = ($filePaths | Where-Object Name -eq "microsoft.subscription_subscriptions-$(($script:subscription.Id).toLower()).json")
        $script:subscriptionDirectory = ($script:subscriptionPath).Directory
        $script:subscriptionFile = ($script:subscriptionPath).FullName
        Write-PSFMessage -Level Debug -Message "SubscriptionFile: $($script:subscriptionFile)" -FunctionName "BeforeAll"

        $script:resourceGroupPath = ($filePaths | Where-Object Name -eq "microsoft.resources_resourcegroups-$(($script:resourceGroup.ResourceGroupName).toLower()).json")
        $script:resourceGroupDirectory = ($script:resourceGroupPath).Directory
        $script:resourceGroupFile = ($script:resourceGroupPath).FullName
        $script:resourceGroupDeploymentName = "AzOps-{0}-{1}" -f $($script:resourceGroupPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "ResourceGroupFile: $($script:resourceGroupFile)" -FunctionName "BeforeAll"

        $script:storageAccountPath = ($filePaths | Where-Object Name -eq "microsoft.storage_storageaccounts-$(($script:storageAccount.Name).toLower()).json")
        $script:storageAccountDirectory = ($script:storageAccountPath).Directory
        $script:storageAccountFile = ($script:storageAccountPath).FullName
        $script:storageAccountDeploymentName = "AzOps-{0}-{1}" -f $($script:storageAccountPath.Name.Replace(".json", '')).Substring(0, 53), $deploymentLocationId
        Write-PSFMessage -Level Debug -Message "StorageAccountFile: $($script:storageAccountFile)" -FunctionName "BeforeAll"
        #endregion Paths

        #Test push based on pulled resources
        $changeSet = @(
            "A`t$script:resourceGroupFile",
            "A`t$script:storageAccountFile"
        )
        Invoke-AzOpsPush -ChangeSet $changeSet
    }

    Context "Test" {

        #region
        # Scope - Root (./root)
        It "Root directory should exist" {
            Test-Path -Path $generatedRoot | Should -BeTrue
        }
        #endregion

        #region Scope - Subscription (./root/subscription-0)
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
            $fileContents.resources[0].type | Should -Be "Microsoft.Subscription/subscriptions"
        }
        #endregion

        #region Scope - Resource Group (./root/subscription-0/TestSubOnly-azopsrg)
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

        #region Scope - Route Table (./root/subscription-0/TestSubOnly-azopsrg/storageaccount)
        It "Storage Account directory should exist" {
            Test-Path -Path $script:storageAccountDirectory | Should -BeTrue
        }
        It "Storage Account file should exist" {
            Test-Path -Path $script:storageAccountFile | Should -BeTrue
        }
        It "Storage Account resource type should exist" {
            $fileContents = Get-Content -Path $script:storageAccountFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -BeTrue
        }
        It "Storage Account resource name should exist" {
            $fileContents = Get-Content -Path $script:storageAccountFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].name | Should -BeTrue
        }
        It "Storage Account resource apiVersion should exist" {
            $fileContents = Get-Content -Path $script:storageAccountFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Storage Account resource properties should exist" {
            $fileContents = Get-Content -Path $script:storageAccountFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].properties | Should -BeTrue
        }
        It "Storage Account resource type should match" {
            $fileContents = Get-Content -Path $script:storageAccountFile -Raw | ConvertFrom-Json -Depth 25
            $fileContents.resources[0].type | Should -Be "Microsoft.Storage/storageAccounts"
        }
        It "Storage Account deployment should be successful" {
            $script:storageAccountDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $script:resourceGroup.ResourceGroupName -Name $script:storageAccountDeploymentName
            $storageAccountDeployment.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion
    }

    AfterAll {

    }

}