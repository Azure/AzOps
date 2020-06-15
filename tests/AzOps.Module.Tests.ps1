Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
Describe "Module Manifest" {
    BeforeAll {
        $ModuleManifestName = 'AzOps.psd1'
        $ModuleManifestPath = "$PSScriptRoot/../src/$ModuleManifestName"
        $ModuleManifest = Test-ModuleManifest -Path $ModuleManifestPath
    }

    Context 'AzOpsManifest' {
        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path $ModuleManifestPath | Should -Not -BeNullOrEmpty
            $? | Should -Be $true
        }

        It 'Passes Test-ModuleManifest RootModule' {
            $ModuleManifest.RootModule | Should -Be 'AzOps.psm1'
        }

        It 'Passes Test-ModuleManifest ModuleVersion' {
            $ModuleManifest.Version | Should -Be '0.0.1'
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