
#
# Functional.Tests.ps1
#
# The tests within this file validate
# that the `Invoke-AzOpsPull` and `Invoke-AzOpsPush`
# functional test is invoking as expected with
# the correct output data for a broad set of Azure resource providers and types.
#
# This file must be invoked by the Tests.ps1
# file as the Global variable testroot is
# required for invocation.
#

Describe "Functional" {

    BeforeAll {

        Write-PSFMessage -Level Verbose -Message "Initializing functional test environment" -FunctionName "BeforeAll"

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
            Set-AzContext -TenantId $script:tenantId -SubscriptionId $script:subscriptionId
        }

        #
        # Deploy the Azure environment
        # based upon prefined resource templates
        # which will generate a matching
        # file system hierachy
        #

        Write-PSFMessage -Level Verbose -Message "Getting functional test objects based on structure" -FunctionName "BeforeAll"
        $script:functionalTestObjectPath = Join-Path $global:testroot -ChildPath "functional"
        $script:testObjects = Get-ChildItem -Path $script:functionalTestObjectPath -Recurse -Filter "deploy.ps1" -File
        Write-PSFMessage -Level Verbose -Message "Found $($script:testObjects.count) functional test objects to deploy" -FunctionName "BeforeAll"
        try {
            Write-PSFMessage -Level Verbose -Message "Executing deploy of functional test objects" -FunctionName "BeforeAll"
            $script:testObjects.VersionInfo.FileName | ForEach-Object -Process {
                & $_
            }
            Start-Sleep -s 60
        }
        catch {
            Write-PSFMessage -Level Warning -String "Executing functional test object failed"
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
            Invoke-AzOpsPull -SkipRole:$false -SkipPolicy:$false -SkipResource:$false -SkipResourceGroup:$false
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
            throw
        }
        # Collect Pulled Files
        $filePaths = (Get-ChildItem -Path $generatedRoot -Recurse)
    }

    Context "Test" {
        #region Scenario
        It "Root directory should exist" {
            Test-Path -Path $generatedRoot | Should -BeTrue
        }

        Write-PSFMessage -Level Debug -Message "GeneratedRootPath: $generatedRoot" -FunctionName "Test"
        $script:testObjectsScenario = Get-ChildItem -Path $script:functionalTestObjectPath -Recurse -Filter "scenario.ps1" -File
        Write-PSFMessage -Level Verbose -Message "Found $($script:testObjectsScenario.count) functional test scenarios" -FunctionName "Test"
        try {
            Write-PSFMessage -Level Verbose -Message "Executing functional test scenarios" -FunctionName "Test"
            $script:testObjectsScenario.VersionInfo.FileName | ForEach-Object -Process {
                & $_
            }
        }
        catch {
            Write-PSFMessage -Level Warning -Message $_ -FunctionName "Test"
        }
        #endregion Scenario
    }

    AfterAll {
        #region Cleanup
        try {
            Write-PSFMessage -Level Verbose -Message "Executing functional test cleanup" -FunctionName "AfterAll"
            # Collect resources to cleanup
            $script:resourceGroups = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -notlike "cloud-shell-storage-*"}
            $script:roleAssignments = Get-AzRoleAssignment | Where-Object {$_.Scope -ne "/"}
            $script:policyAssignments = Get-AzPolicyAssignment
            $script:managementGroups = Get-AzManagementGroup | Where-Object {$_.DisplayName -ne "Tenant Root Group"}
            # Cleanup resourceGroups
            $script:resourceGroups | ForEach-Object -ThrottleLimit 20 -Parallel {
                Write-PSFMessage -Level Verbose -Message "Executing functional test resourceGroups cleanup thread of $($_.ResourceGroupName)" -FunctionName "AfterAll"
                $script:run = $_ | Remove-AzResourceGroup -Confirm:$false -Force
            }
            # Cleanup roleAssignments, policyAssignments and managementGroups
            $script:roleAssignments | Remove-AzRoleAssignment -Confirm:$false
            $script:policyAssignments | Remove-AzPolicyAssignment -Confirm:$false
            foreach ($script:mgclean in $script:managementGroups) {
                Remove-AzManagementGroup -GroupId $script:mgclean.Name -Confirm:$false
            }
            # Collect and cleanup deployment jobs
            $azDeploymentJobs = Get-AzDeployment
            $azDeploymentJobs | ForEach-Object -ThrottleLimit 20 -Parallel {
                Write-PSFMessage -Level Verbose -Message "Executing functional test AzDeployment cleanup thread of $($_.DeploymentName)" -FunctionName "AfterAll"
                $_ | Remove-AzDeployment -Confirm:$false
            }
        }
        catch {
            Write-PSFMessage -Level Warning -Message $_ -FunctionName "AfterAll"
        }
        #endregion Cleanup
    }
}