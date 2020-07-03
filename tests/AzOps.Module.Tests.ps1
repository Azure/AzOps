<#
    .SYNOPSIS
    Pester tests to validate the AzOps Module.

    .DESCRIPTION
    Pester tests to validate the AzOps Module.

    These tests validate the AzOps Module, covering the following categories:

     - PSScriptAnalyzer Tests (-Tag "psscriptanalyzer")
     - Module Manifest Tests (-Tag "manifest")
     - Module Cmdlets Tests (-Tag "cmdlets")

    Tests have been updated to use Pester version 5.0.x

    .EXAMPLE
    To run PSScriptAnalyzer tests only:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "psscriptanalyzer"

    .EXAMPLE
    To run Manifest and Cmdlets tests only, and create test results for CI:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "manifest","cmdlets" -CI

    .EXAMPLE
    To run all module tests, create test results for CI, and output detailed logs to host:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "module", -CI -Output Detailed

    .INPUTS
    None

    .OUTPUTS
    None
#>

Describe "AzOps.Module.PSScriptAnalyzer" -Tag "module", "psscriptanalyzer" {

    BeforeAll {

        $PSScriptAnalyzerConfigPath = "$PSScriptRoot/AzOps.PSScriptAnalyzer.Config.psd1"
        $PSScriptAnalyzerTestPath = "$PSScriptRoot/../src/"

        # Load PSScriptAnalyzer configuration from data file
        $PSScriptAnalyzerConfigError = $null
        $PSScriptAnalyzerConfig = Import-PowerShellDataFile -Path $PSScriptAnalyzerConfigPath -ErrorVariable PSScriptAnalyzerConfigError -ErrorAction SilentlyContinue
        $PSScriptAnalyzerRules = $PSScriptAnalyzerConfig.IncludeRules
        $PSScriptAnalyzerSeverity = $PSScriptAnalyzerConfig.SeverityLevels

        # Define PSScriptAnalyzer Rules which are currently being resolved
        # and should be skipped in Pester tests.
        # These rules will still be evaluated by PSScriptAnalyzer.
        $SkipAnalyzerRulesInPester = @(
            "PSAvoidGlobalVars",
            "PSAvoidTrailingWhitespace",
            "PSAvoidUsingConvertToSecureStringWithPlainText",
            "PSShouldProcess",
            "PSUseBOMForUnicodeEncodedFile",
            "PSUseDeclaredVarsMoreThanAssignments",
            "PSUseOutputTypeCorrectly",
            "PSUseShouldProcessForStateChangingFunctions",
            "PSUseToExportFieldsInManifest"
        )

        # Run PSScriptAnalyzer against specified path
        $PSScriptAnalyzerResultsError = $null
        $PSScriptAnalyzerResults = Invoke-ScriptAnalyzer `
            -Path $PSScriptAnalyzerTestPath `
            -IncludeRule $PSScriptAnalyzerRules `
            -Severity $PSScriptAnalyzerSeverity `
            -Recurse `
            -ErrorVariable PSScriptAnalyzerResultsError `
            -ErrorAction SilentlyContinue

        function Test-PSSAResult ($Rule) {
            # Custom function for evaluating PSScriptAnalyzer Results (DRY)
            # Checks if rule is in the list of rules being tested and skips test if not.
            # Also skips test if found in the SkipAnalyzerRulesInPester list.
            # MISSING FEATURE: Doesn't take into account rules not run due to Severity Level filtering.
            if ($Rule -notin $PSScriptAnalyzerRules) {
                Set-ItResult -Skipped -Because "rule not being tested by PSScriptAnalyzer : $Rule"
            }
            elseif ($PSScriptAnalyzerResults.RuleName -contains $Rule) {
                if ($Rule -notin $SkipAnalyzerRulesInPester) {
                    $PSScriptAnalyzerResults | Where-Object RuleName -EQ $Rule -OutVariable FailedTests
                    $FailedTests.Count | Should -Be 0 -Because $Rule should pass all tests -ErrorAction Continue
                }
                else {
                    Set-ItResult -Skipped -Because "known issues being fixed for rule : $Rule"
                }
            }
        }

    }

    Context "Execution" {

        It "PSScriptAnalyzerConfigPath file path should be valid and exist" {
            $PSScriptAnalyzerConfigPath | Test-Path -PathType Leaf | Should -BeTrue
        }

        It "PSScriptAnalyzerTestPath directory path should be valid and exist" {
            $PSScriptAnalyzerTestPath | Test-Path -PathType Container | Should -BeTrue
        }

        It "PSScriptAnalyzer should load config file from PSScriptAnalyzerConfigPath without errors" {
            $PSScriptAnalyzerConfigError | Should -BeNullOrEmpty
        }

        It "PSScriptAnalyzerRules should contain at least 1 rule" {
            $PSScriptAnalyzerRules.Count | Should -BeGreaterThan 0
        }

        It "PSScriptAnalyzerSeverity should contain 1 to 3 valid severity levels" {
            $PSScriptAnalyzerSeverity.Count | Should -BeGreaterOrEqual 1
            $PSScriptAnalyzerSeverity.Count | Should -BeLessOrEqual 3
            $PSScriptAnalyzerSeverity.foreach(
                {
                    $_ | Should -Match ([regex]::new("(Information|Warning|Error)")) -ErrorAction Continue
                }
            )
        }

        It "PSScriptAnalyzer should run tests without errors" {
            if ($PSScriptAnalyzerResultsError -like "An item with the same key has already been added. Key: ResourceError") {
                Set-ItResult -Inconclusive -Because "known error in task: $PSScriptAnalyzerResultsError"
            }
            else {
                $PSScriptAnalyzerResultsError | Should -BeNullOrEmpty
            }
        }

    }

    Context "Results" {

        It "All PowerShell scripts should pass test: PSAlignAssignmentStatement" {
            Test-PSSAResult "PSAlignAssignmentStatement"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingCmdletAliases" {
            Test-PSSAResult "PSAvoidUsingCmdletAliases"
        }

        It "All PowerShell scripts should pass test: PSAvoidAssignmentToAutomaticVariable" {
            Test-PSSAResult "PSAvoidAssignmentToAutomaticVariable"
        }

        It "All PowerShell scripts should pass test: PSAvoidDefaultValueSwitchParameter" {
            Test-PSSAResult "PSAvoidDefaultValueSwitchParameter"
        }

        It "All PowerShell scripts should pass test: PSAvoidDefaultValueForMandatoryParameter" {
            Test-PSSAResult "PSAvoidDefaultValueForMandatoryParameter"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingEmptyCatchBlock" {
            Test-PSSAResult "PSAvoidUsingEmptyCatchBlock"
        }

        It "All PowerShell scripts should pass test: PSAvoidGlobalAliases" {
            Test-PSSAResult "PSAvoidGlobalAliases"
        }

        It "All PowerShell scripts should pass test: PSAvoidGlobalFunctions" {
            Test-PSSAResult "PSAvoidGlobalFunctions"
        }

        It "All PowerShell scripts should pass test: PSAvoidGlobalVars" {
            Test-PSSAResult "PSAvoidGlobalVars"
        }

        It "All PowerShell scripts should pass test: PSAvoidInvokingEmptyMembers" {
            Test-PSSAResult "PSAvoidInvokingEmptyMembers"
        }

        It "All PowerShell scripts should pass test: PSAvoidLongLines" {
            Test-PSSAResult "PSAvoidLongLines"
        }

        It "All PowerShell scripts should pass test: PSAvoidNullOrEmptyHelpMessageAttribute" {
            Test-PSSAResult "PSAvoidNullOrEmptyHelpMessageAttribute"
        }

        It "All PowerShell scripts should pass test: PSAvoidOverwritingBuiltInCmdlets" {
            Test-PSSAResult "PSAvoidOverwritingBuiltInCmdlets"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingPositionalParameters" {
            Test-PSSAResult "PSAvoidUsingPositionalParameters"
        }

        It "All PowerShell scripts should pass test: PSReservedCmdletChar" {
            Test-PSSAResult "PSReservedCmdletChar"
        }

        It "All PowerShell scripts should pass test: PSReservedParams" {
            Test-PSSAResult "PSReservedParams"
        }

        It "All PowerShell scripts should pass test: PSAvoidShouldContinueWithoutForce" {
            Test-PSSAResult "PSAvoidShouldContinueWithoutForce"
        }

        It "All PowerShell scripts should pass test: PSAvoidTrailingWhitespace" {
            Test-PSSAResult "PSAvoidTrailingWhitespace"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingUsernameAndPasswordParams" {
            Test-PSSAResult "PSAvoidUsingUsernameAndPasswordParams"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingComputerNameHardcoded" {
            Test-PSSAResult "PSAvoidUsingComputerNameHardcoded"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingConvertToSecureStringWithPlainText" {
            Test-PSSAResult "PSAvoidUsingConvertToSecureStringWithPlainText"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingDeprecatedManifestFields" {
            Test-PSSAResult "PSAvoidUsingDeprecatedManifestFields"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingInvokeExpression" {
            Test-PSSAResult "PSAvoidUsingInvokeExpression"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingPlainTextForPassword" {
            Test-PSSAResult "PSAvoidUsingPlainTextForPassword"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingWMICmdlet" {
            Test-PSSAResult "PSAvoidUsingWMICmdlet"
        }

        It "All PowerShell scripts should pass test: PSAvoidUsingWriteHost" {
            Test-PSSAResult "PSAvoidUsingWriteHost"
        }

        It "All PowerShell scripts should pass test: PSUseCompatibleCommands" {
            Test-PSSAResult "PSUseCompatibleCommands"
        }

        It "All PowerShell scripts should pass test: PSUseCompatibleSyntax" {
            Test-PSSAResult "PSUseCompatibleSyntax"
        }

        It "All PowerShell scripts should pass test: PSUseCompatibleTypes" {
            Test-PSSAResult "PSUseCompatibleTypes"
        }

        It "All PowerShell scripts should pass test: PSMisleadingBacktick" {
            Test-PSSAResult "PSMisleadingBacktick"
        }

        It "All PowerShell scripts should pass test: PSMissingModuleManifestField" {
            Test-PSSAResult "PSMissingModuleManifestField"
        }

        It "All PowerShell scripts should pass test: PSPlaceCloseBrace" {
            Test-PSSAResult "PSPlaceCloseBrace"
        }

        It "All PowerShell scripts should pass test: PSPlaceOpenBrace" {
            Test-PSSAResult "PSPlaceOpenBrace"
        }

        It "All PowerShell scripts should pass test: PSPossibleIncorrectComparisonWithNull" {
            Test-PSSAResult "PSPossibleIncorrectComparisonWithNull"
        }

        It "All PowerShell scripts should pass test: PSPossibleIncorrectUsageOfAssignmentOperator" {
            Test-PSSAResult "PSPossibleIncorrectUsageOfAssignmentOperator"
        }

        It "All PowerShell scripts should pass test: PSPossibleIncorrectUsageOfRedirectionOperator" {
            Test-PSSAResult "PSPossibleIncorrectUsageOfRedirectionOperator"
        }

        It "All PowerShell scripts should pass test: PSProvideCommentHelp" {
            Test-PSSAResult "PSProvideCommentHelp"
        }

        It "All PowerShell scripts should pass test: PSReviewUnusedParameter" {
            Test-PSSAResult "PSReviewUnusedParameter"
        }

        It "All PowerShell scripts should pass test: PSUseApprovedVerbs" {
            Test-PSSAResult "PSUseApprovedVerbs"
        }

        It "All PowerShell scripts should pass test: PSUseBOMForUnicodeEncodedFile" {
            Test-PSSAResult "PSUseBOMForUnicodeEncodedFile"
        }

        It "All PowerShell scripts should pass test: PSUseCmdletCorrectly" {
            Test-PSSAResult "PSUseCmdletCorrectly"
        }

        It "All PowerShell scripts should pass test: PSUseCompatibleCmdlets" {
            Test-PSSAResult "PSUseCompatibleCmdlets"
        }

        It "All PowerShell scripts should pass test: PSUseConsistentIndentation" {
            Test-PSSAResult "PSUseConsistentIndentation"
        }

        It "All PowerShell scripts should pass test: PSUseConsistentWhitespace" {
            Test-PSSAResult "PSUseConsistentWhitespace"
        }

        It "All PowerShell scripts should pass test: PSUseCorrectCasing" {
            Test-PSSAResult "PSUseCorrectCasing"
        }

        It "All PowerShell scripts should pass test: PSUseDeclaredVarsMoreThanAssignments" {
            Test-PSSAResult "PSUseDeclaredVarsMoreThanAssignments"
        }

        It "All PowerShell scripts should pass test: PSUseLiteralInitializerForHashtable" {
            Test-PSSAResult "PSUseLiteralInitializerForHashtable"
        }

        It "All PowerShell scripts should pass test: PSUseOutputTypeCorrectly" {
            Test-PSSAResult "PSUseOutputTypeCorrectly"
        }

        It "All PowerShell scripts should pass test: PSUseProcessBlockForPipelineCommand" {
            Test-PSSAResult "PSUseProcessBlockForPipelineCommand"
        }

        It "All PowerShell scripts should pass test: PSUsePSCredentialType" {
            Test-PSSAResult "PSUsePSCredentialType"
        }

        It "All PowerShell scripts should pass test: PSShouldProcess" {
            Test-PSSAResult "PSShouldProcess"
        }

        It "All PowerShell scripts should pass test: PSUseShouldProcessForStateChangingFunctions" {
            Test-PSSAResult "PSUseShouldProcessForStateChangingFunctions"
        }

        It "All PowerShell scripts should pass test: PSUseSupportsShouldProcess" {
            Test-PSSAResult "PSUseSupportsShouldProcess"
        }

        It "All PowerShell scripts should pass test: PSUseToExportFieldsInManifest" {
            Test-PSSAResult "PSUseToExportFieldsInManifest"
        }

        It "All PowerShell scripts should pass test: PSUseUsingScopeModifierInNewRunspaces" {
            Test-PSSAResult "PSUseUsingScopeModifierInNewRunspaces"
        }

        It "All PowerShell scripts should pass test: PSUseUTF8EncodingForHelpFile" {
            Test-PSSAResult "PSUseUTF8EncodingForHelpFile"
        }

        It "All PowerShell scripts should pass test: PSDSCDscExamplesPresent" {
            Test-PSSAResult "PSDSCDscExamplesPresent"
        }

        It "All PowerShell scripts should pass test: PSDSCDscTestsPresent" {
            Test-PSSAResult "PSDSCDscTestsPresent"
        }

        It "All PowerShell scripts should pass test: PSDSCReturnCorrectTypesForDSCFunctions" {
            Test-PSSAResult "PSDSCReturnCorrectTypesForDSCFunctions"
        }

        It "All PowerShell scripts should pass test: PSDSCUseIdenticalMandatoryParametersForDSC" {
            Test-PSSAResult "PSDSCUseIdenticalMandatoryParametersForDSC"
        }

        It "All PowerShell scripts should pass test: PSDSCUseIdenticalParametersForDSC" {
            Test-PSSAResult "PSDSCUseIdenticalParametersForDSC"
        }

        It "All PowerShell scripts should pass test: PSDSCStandardDSCFunctionsInResource" {
            Test-PSSAResult "PSDSCStandardDSCFunctionsInResource"
        }

        It "All PowerShell scripts should pass test: PSDSCUseVerboseMessageInDSCResource" {
            Test-PSSAResult "PSDSCUseVerboseMessageInDSCResource"
        }

    }

}

# The following code snippet is used to generate all of the above tests for the Context "Results" block.
# Once generated, the content of the pester.ps1 file should be copied into this script and pester.ps1 can be deleted.
# To run, just highlight the text and press F8 (or copy and paste into a PowerShell terminal)

<#
$Rules = Get-ScriptAnalyzerRule
$Tests = @()
foreach ($Rule in $Rules) {
    $Tests += "
    It `"All PowerShell scripts should pass test: $Rule`" {
        Test-PSSAResult `"$Rule`"
    }"
}
$Tests | Out-File ./pester.ps1
#>

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

        It 'Passes Test-ModuleManifest ModuleVersion' {
            $ModuleManifest.Version | Should -Be '0.2'
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
            $ModuleManifest.Author | Should -Be 'Customer Engineering'
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
        $env:AzOpsState = $TestDrive
        $env:InvalidateCache = 1
        $env:AzOpsMainTemplate = ("$PSScriptRoot/../src/template.json")
        $env:AzOpsStateConfig = ("$PSScriptRoot/../src/AzOpsStateConfig.json")
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
        It "Passes returns null when no duplicate subscriptions or Management Groups found" {
            $SingleTest | Should -BeNullOrEmpty
        }

    }

}
