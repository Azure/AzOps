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
Describe 'PSScriptAnalyzer Tests' {

    BeforeAll {

        $PSScriptAnalyzerConfigPath = "$($PWD.Path)/tests/AzOps.PSScriptAnalyzer.Config.psd1"
        $PSScriptAnalyzerTestPath = "$($PWD.Path)/"
    
        # Load PSScriptAnalyzer configuration from data file
        $PSScriptAnalyzerConfigError = $null
        $PSScriptAnalyzerConfig = Import-PowerShellDataFile -Path $PSScriptAnalyzerConfigPath -ErrorVariable PSScriptAnalyzerConfigError -ErrorAction SilentlyContinue
        $PSScriptAnalyzerRules = $PSScriptAnalyzerConfig.IncludeRules
        $PSScriptAnalyzerSeverity = $PSScriptAnalyzerConfig.SeverityLevels
    
        # Run PSScriptAnalyzer against specified path
        $PSScriptAnalyzerResultsError = $null
        $PSScriptAnalyzerResults = Invoke-ScriptAnalyzer `
            -Path $PSScriptAnalyzerTestPath `
            -IncludeRule $PSScriptAnalyzerRules `
            -Severity $PSScriptAnalyzerSeverity `
            -Recurse `
            -ErrorVariable PSScriptAnalyzerResultsError `
            -ErrorAction SilentlyContinue
    
    }
    
    Context "PSScriptAnalyzer Execution" {

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
                Set-ItResult -Inconclusive -Because "None fatal known error in task: $PSScriptAnalyzerResultsError"
            }
            else {
                $PSScriptAnalyzerResultsError | Should -BeNullOrEmpty
            }
        }

    }

    Context "PSScriptAnalyzer Test Results" {

        It "All PSScriptAnalyzer tests should pass" {
            foreach ($Rule in $PSScriptAnalyzerRules) {
                if ($PSScriptAnalyzerResults.RuleName -contains $Rule) {
                    $PSScriptAnalyzerResults | Where-Object RuleName -EQ $Rule -OutVariable FailedTests
                    $FailedTestsCount = $FailedTests.Count
                    $FailedTestsCount | Should -Be 0 -Because $("$Rule should pass all tests") -ErrorAction Continue
                }
            }
        }

    }

}
