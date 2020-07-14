<#
    .SYNOPSIS
    Pester tests to validate the AzOps Module.

    .DESCRIPTION
    Pester tests to validate the AzOps Module.

    These tests validate the AzOps Module, covering the following categories:

     - Module Manifest Tests (-Tag "manifest")
     - Module Cmdlets Tests (-Tag "cmdlets")

    Tests have been updated to use Pester version 5.0.x

    .EXAMPLE
    To run Cmdlets tests only:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "cmdlets"

    .EXAMPLE
    To run Cmdlets tests only, and create test results for CI:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "cmdlets" -CI

    .EXAMPLE
    To run all module tests, create test results for CI, and output detailed logs to host:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "module" -CI -Output Detailed

    .INPUTS
    None

    .OUTPUTS
    None
#>

# The following SuppressMessageAttribute entries are used to surpress
# PSScriptAnalyzer tests against known exceptions as per:
# https://github.com/powershell/psscriptanalyzer#suppressing-rules
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ModuleManifest')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'TestHt')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'TestPSCustomObject')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'policyDefinition')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'policyAssignment')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'policySetDefinition')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'resourceGroup')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DuplicateTest')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'SingleTest')]
param()

Describe "AzOps.Module.Manifest" -Tag "module", "manifest" {

    BeforeAll {

        # Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
        $ModuleManifestName = 'AzOps.psd1'
        $ModuleManifestPath = "$PSScriptRoot/../src/$ModuleManifestName"
        $ModuleManifest = Test-ModuleManifest -Path $ModuleManifestPath
    }

    Context 'Validation' {
        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path $ModuleManifestPath | Should -Not -BeNullOrEmpty
            $? | Should -Be $true
        }

        It 'Passes Test-ModuleManifest RootModule' {
            $ModuleManifest.RootModule | Should -Be 'AzOps.psm1'
        }

        It 'Passes Test-ModuleManifest Copyright' {
            $ModuleManifest.Copyright | Should -Be '(c) Microsoft. All rights reserved.'
        }

        It 'Passes Test-ModuleManifest PowerShellVersion' {
            $ModuleManifest.PowerShellVersion | Should -Be '7.0'
        }

        It 'Passes Test-ModuleManifest GUID' {
            $ModuleManifest.Guid | Should -Be '4336cc9b-48f8-4b0e-9629-fd1245e848d9'
        }

        It 'Passes Test-ModuleManifest Author' {
            $ModuleManifest.Author | Should -Be 'Customer Architecture and Engineering'
        }

        It 'Passes Test-ModuleManifest CompanyName' {
            $ModuleManifest.CompanyName | Should -Be 'Microsoft'
        }

        It 'Passes Test-ModuleManifest RequiredModules' {
            $ModuleManifest.RequiredModules | Should -Be @(
                'Az.Accounts',
                'Az.Resources'
            )
        }

        It 'Passes Test-ModuleManifest FunctionsToExport' {
            $ModuleManifest.ExportedFunctions.Keys | Should -Be @(
                'Initialize-AzOpsGlobalVariables',
                'Initialize-AzOpsRepository',
                'Invoke-AzOpsGitPull',
                'Invoke-AzOpsGitPush',
                'New-AzOpsScope'
            )
        }

    }
}

Describe "AzOps.Module.Cmdlets" -Tag "module", "cmdlets" {

    BeforeAll {

        # Import required modules
        Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
        Get-ChildItem "$PSScriptRoot/../src/private" -Force | ForEach-Object -Process { . $_.FullName }
        # Set required variables
        $env:AZOPS_STATE = $TestDrive
        $env:AZOPS_INVALIDATE_CACHE = 1
        $env:AZOPS_MAIN_TEMPLATE = ("$PSScriptRoot/../src/template.json")
        $env:AZOPS_STATE_CONFIG = ("$PSScriptRoot/../src/AzOpsStateConfig.json")
        Initialize-AzOpsGlobalVariables

    }

    Context "ConvertTo-AzOpsObject" {

        BeforeAll {

            $TestHt = [ordered]@{
                "z" = "z"
                "d" = "d"
                "a" = "a"
            }
            $TestPSCustomObject = [PSCustomObject][ordered]@{
                "z" = "z"
                "d" = "d"
                "a" = "a"
            }

        }

        It "Passes conversion of strongly typed object to [PSCustomObject]" {
            ConvertTo-AzOpsObject -InputObject (Get-AzPolicyDefinition -Custom | Get-Random) | Should -BeOfType [PSCustomObject]
        }
        It "Passes ordering of hashtable" {
            [array]($TestHt | ConvertTo-AzOpsObject -OrderObject).Keys | Select-Object -Last 1 | Should -BeExactly "z"
        }
        It "Passes ordering of PSCustomObject" {
            ($TestPSCustomObject | ConvertTo-AzOpsObject -OrderObject).psobject.properties.name | Select-Object -Last 1 | Should -BeExactly "z"
        }
        It "Passes return empty array as array" {
            , @() | ConvertTo-AzOpsObject -OrderObject | Should -BeOfType [array]
        }
        It "Passes ordering of array" {
            ConvertTo-AzOpsObject -InputObject @("z", "d", "a", "f") -OrderObject | Select-Object -Last 1 | Should -BeExactly "z"
        }

    }

    Context "ConvertTo-AzOpsState" {

        BeforeAll {

            # Get Resources
            $policyDefinition = Get-AzPolicyDefinition -ManagementGroupName Contoso | Get-Random
            $policyAssignment = Get-AzPolicyAssignment -Scope /providers/Microsoft.Management/managementGroups/contoso | Get-Random
            $policySetDefinition = Get-AzPolicySetDefinition -Custom -ManagementGroupName Contoso | Get-Random
            $resourceGroup = Get-AzResourceGroup | Get-Random

        }

        # Validate default exclusion of properties - metadata should always be excluded for policy objects
        It "Passes policyDefinition default exclusion of properties" {
            (Get-Member -InputObject (ConvertTo-AzOpsState -Resource $policyDefinition -ReturnObject).parameters.input.value.properties).Name | Should -Not -Contain Metadata
        }
        It "Passes policyAssignment default exclusion of properties" {
            (Get-Member -InputObject (ConvertTo-AzOpsState -Resource $policyAssignment -ReturnObject).parameters.input.value.properties).Name | Should -Not -Contain Metadata
        }
        It "Passes policysetDefiniton default exclusion of properties" {
            (Get-Member -InputObject (ConvertTo-AzOpsState -Resource $policySetDefinition -ReturnObject).parameters.input.value.properties).Name | Should -Not -Contain Metadata
        }
        It "Passes resourceGroup default exclusion of properties" {
            (Get-Member -InputObject (ConvertTo-AzOpsState -Resource $resourceGroup -ReturnObject).parameters.input.value).Name | Should -Not -Contain TagsTable
        }

    }

    Context "Test-AzOpsDuplicateSubMgmtGroup" {

        BeforeAll {

            # Mock Subscription object
            $Subscriptions = 1..3 | ForEach-Object -Process { [pscustomobject]@{ Name = "Subscription 1" ; Id = New-Guid } }
            # Mock managementgroup object
            $ManagementGroups = 1..3  | ForEach-Object -Process { [pscustomobject]@{ DisplayName = "Management Group 1" ; Id = New-Guid } }
            # Test cmdlet against mock data to return output
            $DuplicateTest = Test-AzOpsDuplicateSubMgmtGroup -Subscriptions $Subscriptions -ManagementGroups $ManagementGroups
            # Test cmdlet against inputdata with 1 Subscription/Management Group
            $SingleTest = Test-AzOpsDuplicateSubMgmtGroup -Subscription ($Subscriptions | Select-Object -First 1) -ManagementGroups ($ManagementGroups | Select-Object -First 1)

        }

        It "Passes returns 3 Management Groups with duplicate names" {
            ($DuplicateTest | Where-Object { $_.Type -eq "ManagementGroup" }).Count | Should -BeExactly 3
        }
        It "Passes returns 3 subscriptions with duplicate names" {
            ($DuplicateTest | Where-Object { $_.Type -eq "Subscription" }).Count | Should -BeExactly 3
        }
    }

}
