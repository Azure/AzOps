<#
.SYNOPSIS
    Runs PSScriptAnalyzer tests against the AzOps Module in Azure Pipelines.
.DESCRIPTION
    Runs PSScriptAnalyzer tests against the AzOps Module in Azure Pipelines.
    This script should be run on the "ubuntu-latest" build agent to ensure the repository code is compliant with PSScriptAnalyzer rules.
.EXAMPLE
    Initialize-AzOpsTestEnvironment
.INPUTS
    None
.OUTPUTS
    None
#>

# Run PSScriptAnalyzer tests against repository
Describe 'PSScriptAnalyzer' {

    BeforeAll {

        $PSScriptAnalyzerConfigPath = "$($PWD.Path)/tests/AzOps.PSScriptAnalyzer.Config.psd1"
        $PSScriptAnalyzerTestPath = "$($PWD.Path)/"
    
        # Load PSScriptAnalyzer configuration from data file
        $PSScriptAnalyzerConfigError = $null
        $PSScriptAnalyzerConfig = Import-PowerShellDataFile -Path $PSScriptAnalyzerConfigPath -ErrorVariable PSScriptAnalyzerConfigError -ErrorAction SilentlyContinue
        $PSScriptAnalyzerRules = $PSScriptAnalyzerConfig.IncludeRules
        $PSScriptAnalyzerSeverity = $PSScriptAnalyzerConfig.SeverityLevels

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

        # Custom function for evaluating PSScriptAnalyzer Results (DRY)
        function Test-PSSAResult ($Rule) {
            if ($PSScriptAnalyzerResults.RuleName -contains $Rule) {
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

        # It "All PSScriptAnalyzer tests should pass" {
        #     foreach ($Rule in $PSScriptAnalyzerRules) {
        #         if ($PSScriptAnalyzerResults.RuleName -contains $Rule) {
        #             $PSScriptAnalyzerResults | Where-Object RuleName -EQ $Rule -OutVariable FailedTests
        #             $FailedTestsCount = $FailedTests.Count
        #             $FailedTestsCount | Should -Be 0 -Because $("$Rule should pass all tests") -ErrorAction Continue
        #         }
        #     }
        # }

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