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

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateScript( { $_ | Test-Path })]
    [String]$PSScriptAnalyzerConfigPath = "./tests/AzOps.PSScriptAnalyzer.Config.psd1",
    [Parameter()]
    [ValidateScript( { $_ | Test-Path })]
    [String]$PSScriptAnalyzerTestPath = "./"
)

# Run PSScriptAnalyzer tests against repository
Describe 'PSScriptAnalyzer Tests' {

    # Load PSScriptAnalyzer configuration from data file
    try {
        $PSScriptAnalyzerConfig = Import-PowerShellDataFile -Path $PSScriptAnalyzerConfigPath -ErrorAction Stop
        $PSScriptAnalyzerRules = $PSScriptAnalyzerConfig.IncludeRules
        $PSScriptAnalyzerConfigError = $null
    }
    catch {
        $PSScriptAnalyzerConfigError = $($_.Exception.Message)
    }

    try {
        $PSScriptAnalyzerResults = Invoke-ScriptAnalyzer `
            -Path $PSScriptAnalyzerTestPath `
            -IncludeRule $PSScriptAnalyzerRules `
            -Recurse `
            -ErrorAction Stop
        $PSScriptAnalyzerResultsError = $null
    }
    catch {
        $PSScriptAnalyzerResultsError = $($_.Exception.Message)
    }

    Context "Execute PSScriptAnalyzer" {

        It "PSScriptAnalyzer PSScriptAnalyzerConfigPath file path should be valid and exist" {
            Test-Path -Path $PSScriptAnalyzerConfigPath | Should Be $True Because "$PSScriptAnalyzerConfigPath is invalid or does not exist"
        }

        It "PSScriptAnalyzer should load config file from PSScriptAnalyzerConfigPath without errors" {
            $PSScriptAnalyzerConfigError | Should BeNullOrEmpty Because $PSScriptAnalyzerConfigError
        }

        It "PSScriptAnalyzer PSScriptAnalyzerTestPath file path should be valid and exist" {
            Test-Path -Path $PSScriptAnalyzerTestPath | Should Be $True Because "$PSScriptAnalyzerTestPath is invalid or does not exist"
        }

        It "PSScriptAnalyzer should run tests without errors" {
            $PSScriptAnalyzerResultsError | Should BeNullOrEmpty Because $PSScriptAnalyzerResultsError
        }

    }

    Context "Evaluate PSScriptAnalyzer Results" {

        foreach ($Rule in $PSScriptAnalyzerRules) {
            It "All PowerShell files should pass PSScriptAnalyzer rule: $($Rule)" {
                if ($PSScriptAnalyzerResults.RuleName -contains $Rule) {
                    $PSScriptAnalyzerResults | Where-Object RuleName -EQ $Rule -OutVariable FailedTests
                    $FailedTestsCount = $FailedTests.Count
                    $FailedTestsCount | Should Be 0
                }
            }
        }

    }

}
