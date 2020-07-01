<#
    .SYNOPSIS
    Pester tests to validate the AzOps Module for "In a Box" deployments.

    .DESCRIPTION
    Pester tests to validate the AzOps Module for "In a Box" deployments.

    These tests validate using the AzOps Module to perform the following deployment scenarios:

     - "In a Box" end-to-end deployment (-Tag "iab")

    Tests have been updated to use Pester version 5.0.x

    .EXAMPLE
    To run "In a Box" tests only:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab"

    .EXAMPLE
    To run "In a Box" tests only, and create test results for CI:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab" -CI

    .EXAMPLE
    To run "In a Box", create test results for CI, and output detailed logs to host:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "iab" -CI -Output Detailed

    .INPUTS
    None

    .OUTPUTS
    None
#>

Describe "Tenant E2E Deployment (Integration Test)" -Tag "integration", "e2e", "iab" {

    BeforeAll {

        # Import AzOps Module
        Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
        # Make private functions from AzOps Module available for BeforeAll block
        (Get-ChildItem "./src/private/*.ps1").FullName | Import-Module -Force

        #region setup
        # Task: Initialize environment variables
        $env:AzOpsState = $TestDrive
        $env:InvalidateCache = 1
        $env:AzOpsMainTemplate = ("$PSScriptRoot/../template/template.json")
        $env:AzOpsStateConfig = ("$PSScriptRoot/../src/AzOpsStateConfig.json")

        #Use AzOpsReference published in https://github.com/Azure/Enterprise-Scale
        Start-AzOpsNativeExecution {
            git clone 'https://github.com/Azure/Enterprise-Scale'
        } | Out-Host
        $AzOpsReferenceFolder = (Join-Path $pwd -ChildPath 'Enterprise-Scale/azopsreference')
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "AzOpsReferenceFolder Path is: $AzOpsReferenceFolder"

        # Task: Check if 'Tailspin' Management Group exists
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Removing Tailspin Management Group"
        if (Get-AzManagementGroup -GroupName 'Tailspin' -ErrorAction SilentlyContinue) {
            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Running Remove-AzOpsManagementGroup"
            Remove-AzOpsManagementGroup -GroupName  'Tailspin'
        }
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Tailspin Management Group hierarchy removed."
        #endregion

        # Task: Initialize azops/
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Running Initialize-AzOpsRepository"
        Initialize-AzOpsRepository -SkipResourceGroup -SkipPolicy

        # Comment: Find Tenant Root Group id
        $tenantName = ($global:AzOpsAzManagementGroup | Where-Object -FilterScript { $_.ParentDisplayName -eq $null }).DisplayName

        # Task: Deployment of 10-create-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/10-create-managementgroup.parameters.json" | ForEach-Object {
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Running New-AzOpsStateDeployment for 10-create-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
        }

        # Task: Deployment of 20-create-child-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/20-create-child-managementgroup.parameters.json" | ForEach-Object {
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Running New-AzOpsStateDeployment for 20-create-child-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
        }

        # Task: Deployment of 30-create-policydefinition-at-managementgroup.parameters.json
        Get-ChildItem -Path "$PSScriptRoot/../template/30-create-policydefinition-at-managementgroup.parameters.json" | ForEach-Object {
            Copy-Item -Path $_.FullName  -Destination $TestDrive
            $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
            $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Running New-AzOpsStateDeployment for 30-create-policydefinition-at-managementgroup.parameters.json"
            New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
        }

        <# State: Disabling this due to bug where Policy assignment fails for first time.

            Get-ChildItem -Path "$PSScriptRoot/../template/40-create-policyassignment-at-managementgroup.parameters.json" | ForEach-Object {
                Copy-Item -Path $_.FullName  -Destination $TestDrive
                $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
                $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
                $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)
                New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
            }

            #>

        # Task: Re-initialize azops/
        Initialize-AzOpsRepository -SkipResourceGroup -SkipPolicy
    }

    Context "In-a-Box" {
        # Debug: Get-AzTenantDeployment | Sort-Object -Property Timestamp -Descending | Format-Table
        It "Passes ProvisioningState 10-create-managementgroup" {
            (Get-AzTenantDeployment -Name "10-create-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes ProvisioningState 20-create-child-managementgroup" {
            (Get-AzTenantDeployment -Name "20-create-child-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes ProvisioningState 30-create-policydefinition-at-managementgroup" {
            (Get-AzTenantDeployment -Name "30-create-policydefinition-at-managementgroup").ProvisioningState | Should -Match "Succeeded"
        }
        It "Passes Discovery of Tailspin Management Group" {
            (Get-ChildItem -Directory -Recurse -Path $env:AzOpsState).Name | Should -Contain 'Tailspin'
        }

        It "Passes Policy Definition Test" {
            $TailspinAzOpsState = ((Get-ChildItem -Recurse -Directory -path $env:AzOpsState) | Where-Object { $_.Name -eq 'Tailspin' }).FullName
            $AzOpsReferencePolicyCount = (Get-ChildItem "$AzOpsReferenceFolder/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policyDefinitions*.json").count
            foreach ($policyDefinition in (Get-ChildItem "$AzOpsReferenceFolder/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policyDefinitions*.json")) {
                Copy-Item $policyDefinition $TailspinAzOpsState -Force
            }
            foreach ($policyDefinition in (Get-ChildItem "$TailspinAzOpsState/Microsoft.Authorization_policyDefinitions*.json")) {
                # Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Deploying Policy Definition: $policyDefinition"
                $scope = New-AzOpsScope -path $policyDefinition.FullName
                $deploymentName = (Get-Item $policyDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                if ($deploymentName.Length -gt 64) {
                    $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                }
                New-AzManagementGroupDeployment -Location  $env:AzOpsDefaultDeploymentRegion -TemplateFile $env:AzOpsMainTemplate -TemplateParameterFile $policyDefinition.FullName -ManagementGroupId $scope.managementGroup -Name $deploymentName -AsJob
            }

            Get-Job | Wait-Job

            # Comment: There is an unexplained delay between successful deployment -> and GET.
            $timeout = New-TimeSpan -Minutes 5
            $stopwatch = [diagnostics.stopwatch]::StartNew()

            $tailspinJsonCount = 0
            while ($stopwatch.elapsed -lt $timeout) {

                # Comment: Refresh Policy at Tailspin scope
                Get-AzOpsResourceDefinitionAtScope -scope (New-AzOpsScope -path $TailspinAzOpsState)
                $tailspinJson = Get-Content -path (New-AzOpsScope -path $TailspinAzOpsState).statepath | ConvertFrom-Json
                $tailspinJsonCount = $tailspinJson.parameters.input.value.properties.policyDefinitions.Count
                if ($tailspinJsonCount -lt $AzOpsReferencePolicyCount) {
                    Start-Sleep -Seconds 30
                }
                else {
                    break
                }
            }

            $tailspinJsonCount | Should -Be $AzOpsReferencePolicyCount
        }

        It "Passes PolicySet Definition Test" {
            $TailspinAzOpsState = ((Get-ChildItem -Recurse -Directory -path $env:AzOpsState) | Where-Object { $_.Name -eq 'Tailspin' }).FullName
            $AzOpsReferencePolicySetCount = (Get-ChildItem "$AzOpsReferenceFolder/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policySetDefinitions*.json").count
            foreach ($policySetDefinition in (Get-ChildItem "$AzOpsReferenceFolder/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policySetDefinitions*.json")) {
                Copy-Item $policySetDefinition $TailspinAzOpsState -Force
            }
            foreach ($policySetDefinition in (Get-ChildItem "$TailspinAzOpsState/Microsoft.Authorization_policySetDefinitions*.json")) {
                # Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Deploying Policy Definition: $policySetDefinition"

                # Changing the Scope to match Tailspin
                (Get-Content -path $policySetDefinition -Raw) -replace '/providers/Microsoft.Management/managementGroups/contoso/', '/providers/Microsoft.Management/managementGroups/Tailspin/' | Set-Content -Path $policySetDefinition

                $scope = New-AzOpsScope -path $policySetDefinition.FullName

                $deploymentName = (Get-Item $policySetDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                if ($deploymentName.Length -gt 64) {
                    $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                }
                New-AzManagementGroupDeployment -Location  $env:AzOpsDefaultDeploymentRegion `
                    -TemplateFile $env:AzOpsMainTemplate `
                    -TemplateParameterFile $policySetDefinition.FullName `
                    -ManagementGroupId $scope.managementGroup `
                    -Name $deploymentName -AsJob
            }

            Get-Job | Wait-Job

            # There is an unexplained delay between successful deployment -> and GET.
            $timeout = New-TimeSpan -Minutes 5
            $sw = [diagnostics.stopwatch]::StartNew()
            $tailspinJsonSetCount = 0
            while ($sw.elapsed -lt $timeout) {

                # Refresh Policy at Tailspin scope
                Get-AzOpsResourceDefinitionAtScope -scope (New-AzOpsScope -path $TailspinAzOpsState)
                $tailspinJson = Get-Content -path (New-AzOpsScope -path $TailspinAzOpsState).statepath | ConvertFrom-Json
                $tailspinJsonSetCount = $tailspinJson.parameters.input.value.properties.policySetDefinitions.Count
                if ($tailspinJsonSetCount -lt $AzOpsReferencePolicySetCount) {
                    start-sleep -seconds 30
                }
                else {
                    break
                }
            }
            $tailspinJsonSetCount | Should -Be $AzOpsReferencePolicySetCount
        }
    }

    AfterAll {
        # Cleaning up Tailspin Management Group
        # Disabling until pull for IAB pull is wired up
        # if(Get-AzManagementGroup -GroupName 'Tailspin' -ErrorAction SilentlyContinue)
        # {
        #     Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Cleaning up Tailspin Management Group"
        #     Remove-AzOpsManagementGroup -groupName  'Tailspin'
        # }
    }
}
