Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force

InModuleScope 'AzOps' {

    Describe "E2E Integration Test for Tenant Deployment" {

        BeforeAll {
            Write-Output " "

            # Task: Initialize environment variables
            $env:AzOpsState = $TestDrive
            $env:InvalidateCache = 1
            $env:AzOpsMasterTemplate = ("$PSScriptRoot/../template/template.json")
            $env:AzOpsStateConfig = ("$PSScriptRoot/../src/AzOpsStateConfig.json")

            # Task: Check if 'Tailspin' Management Group exists
            if (Get-AzManagementGroup -GroupName 'Tailspin' -ErrorAction SilentlyContinue) {
                Write-Output "   - Running Remove-AzOpsManagementGroup"
                Remove-AzOpsManagementGroup -GroupName  'Tailspin'
            }

            # Task: Initialize azops/
            Write-Output "   - Running Initialize-AzOpsRepository"
            Initialize-AzOpsRepository -SkipResourceGroup -SkipPolicy

            # Comment: Find Tenant Root Group id
            $tenantName = ($global:AzOpsAzManagementGroup | Where-Object -FilterScript { $_.ParentDisplayName -eq $null }).DisplayName

            # Task: Deployment of 10-create-managementgroup.parameters.json
            Get-ChildItem -Path "$PSScriptRoot/parameters/10-create-managementgroup.parameters.json" | ForEach-Object {
                Copy-Item -Path $_.FullName  -Destination $TestDrive
                $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
                $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
                $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

                Write-Output "   - Running New-AzOpsStateDeployment for 10-create-managementgroup.parameters.json"
                New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
            }

            # Task: Deployment of 20-create-child-managementgroup.parameters.json
            Get-ChildItem -Path "$PSScriptRoot/parameters/20-create-child-managementgroup.parameters.json" | ForEach-Object {
                Copy-Item -Path $_.FullName  -Destination $TestDrive
                $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
                $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
                $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

                Write-Output "   - Running New-AzOpsStateDeployment for 20-create-child-managementgroup.parameters.json"
                New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
            }

            # Task: Deployment of 30-create-policydefinition-at-managementgroup.parameters.json
            Get-ChildItem -Path "$PSScriptRoot/parameters/30-create-policydefinition-at-managementgroup.parameters.json" | ForEach-Object {
                Copy-Item -Path $_.FullName  -Destination $TestDrive
                $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
                $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
                $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)

                Write-Output "   - Running New-AzOpsStateDeployment for 30-create-policydefinition-at-managementgroup.parameters.json"
                New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
            }

            # State: Disabling this due to bug where Policy assignment fails for first time.
            # Get-ChildItem -Path "$PSScriptRoot/parameters/40-create-policyassignment-at-managementgroup.parameters.json" | ForEach-Object {
            #     Copy-Item -Path $_.FullName  -Destination $TestDrive
            #     $content = Get-Content -Path (Join-Path -Path $TestDrive -ChildPath $_.Name) | ConvertFrom-Json -Depth 100
            #     $content.parameters.input.value.ParentId = ("/providers/Microsoft.Management/managementGroups/" + (Get-AzTenant).Id)
            #     $content | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path -Path $TestDrive -ChildPath $_.Name)
            #     New-AzOpsStateDeployment -FileName (Join-Path -Path $TestDrive -ChildPath $_.Name)
            # }
            #

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
                $TailspinAzOpsState = ((Get-ChildItem -Recurse -Directory -path $env:AzOpsState) | Where-Object  { $_.Name -eq 'Tailspin' }).FullName
                $AzOpsReferencePolicyCount = (Get-ChildItem "$PSScriptRoot/reference/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policyDefinitions*.json").count
                foreach ($policyDefinition in (Get-ChildItem "$PSScriptRoot/reference/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policyDefinitions*.json")) {
                    Copy-Item $policyDefinition $TailspinAzOpsState -Force
                }
                foreach ($policyDefinition in (Get-ChildItem "$TailspinAzOpsState/Microsoft.Authorization_policyDefinitions*.json")) {
                    #Write-Output "   - Deploying Policy Definition: $policyDefinition"
                    $scope = New-AzOpsScope -path $policyDefinition.FullName
                    $deploymentName = (Get-Item $policyDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                    if ($deploymentName.Length -gt 64) {
                        $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                    }
                    New-AzManagementGroupDeployment -Location  $env:AzOpsDefaultDeploymentRegion -TemplateFile $env:AzOpsMasterTemplate -TemplateParameterFile $policyDefinition.FullName -ManagementGroupId $scope.managementGroup -Name $deploymentName -AsJob
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
                $TailspinAzOpsState = ((Get-ChildItem -Recurse -Directory -path $env:AzOpsState) | Where-Object  { $_.Name -eq 'Tailspin' }).FullName
                $AzOpsReferencePolicySetCount = (Get-ChildItem "$PSScriptRoot/reference/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policySetDefinitions*.json").count
                foreach ($policySetDefinition in (Get-ChildItem "$PSScriptRoot/reference/3fc1081d-6105-4e19-b60c-1ec1252cf560/contoso/.AzState/Microsoft.Authorization_policySetDefinitions*.json")) {
                    Copy-Item $policySetDefinition $TailspinAzOpsState -Force
                }
                foreach ($policySetDefinition in (Get-ChildItem "$TailspinAzOpsState/Microsoft.Authorization_policySetDefinitions*.json")) {
                    #Write-Verbose "Deploying Policy Definition: $policySetDefinition"

                    #Changing the Scope to match Tailspin
                    (Get-Content -path $policySetDefinition -Raw) -replace '/providers/Microsoft.Management/managementGroups/contoso/', '/providers/Microsoft.Management/managementGroups/Tailspin/' | Set-Content -Path $policySetDefinition

                    $scope = New-AzOpsScope -path $policySetDefinition.FullName

                    $deploymentName = (Get-Item $policySetDefinition).BaseName.replace('.parameters', '').Replace(' ', '_')
                    if ($deploymentName.Length -gt 64) {
                        $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                    }
                    New-AzManagementGroupDeployment -Location  $env:AzOpsDefaultDeploymentRegion `
                        -TemplateFile $env:AzOpsMasterTemplate `
                        -TemplateParameterFile $policySetDefinition.FullName `
                        -ManagementGroupId $scope.managementGroup `
                        -Name $deploymentName -AsJob
                }

                Get-Job | Wait-Job

                #There is an unexplained delay between successful deployment -> and GET.
                $timeout = New-TimeSpan -Minutes 5
                $sw = [diagnostics.stopwatch]::StartNew()
                $tailspinJsonSetCount = 0
                while ($sw.elapsed -lt $timeout) {

                    #Refresh Policy at Tailspin scope
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
            #     Write-Verbose "Cleaning up Tailspin Management Group"
            #     Remove-AzOpsManagementGroup -groupName  'Tailspin'
            # }
        }
    }
}
