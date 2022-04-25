Describe "Scenario - vaults" {

    BeforeAll {
        $script:resourceProvider = (Resolve-Path $PSScriptRoot).Path.Split('/')[-2]
        $script:resourceType = (Resolve-Path $PSScriptRoot).Path.Split('/')[-1]
        $script:functionalTestDeploy = Get-Variable -Name (($script:resourceType) + 'FunctionalTestDeploy') -Scope Global

        #region Paths
        $script:path = ($global:functionalTestFilePaths | Where-Object Name -eq "$($script:resourceProvider)_$($script:resourceType)-$(($script:functionalTestDeploy.value.parameters.vaultName.value).toLower()).json")
        $script:directory = ($script:path).Directory
        $script:file = ($script:path).FullName
        $script:fileContents = Get-Content -Path $script:file -Raw | ConvertFrom-Json -Depth 25
        Write-PSFMessage -Level Debug -Message "TestResoucePath: $($script:file)" -FunctionName "Functional Tests"
        #endregion Paths

        #region Push Primer
        $changeSet = @(
            "A`t$script:file"
        )
        try {
            Write-PSFMessage -Level Debug -Message "Push Scenario $script:resourceType starting: $script:file" -FunctionName "Functional Tests"
            $script:push = Invoke-AzOpsPush -ChangeSet $changeSet
            Write-PSFMessage -Level Debug -Message "Push Scenario $script:resourceType completed: $script:file" -FunctionName "Functional Tests"
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Push Scenario $script:resourceType failed: $script:file" -Exception $_.Exception
        }
        #endregion Push Primer
    }

    Context "Test" {
        #region Pull Test
        It "Directory should exist" {
            Test-Path -Path $script:Directory | Should -BeTrue
        }
        It "File should exist" {
            Test-Path -Path $script:file | Should -BeTrue
        }
        It "Resource type should exist" {
            $script:fileContents.resources[0].type | Should -BeTrue
        }
        It "Resource name should exist" {
            $script:fileContents.resources[0].name | Should -BeTrue
        }
        It "Resource apiVersion should exist" {
            $script:fileContents.resources[0].apiVersion | Should -BeTrue
        }
        It "Resource properties should exist" {
            $script:fileContents.resources[0].properties | Should -BeTrue
        }
        It "Resource type should match" {
            $script:fileContents.resources[0].type | Should -Be "$script:resourceProvider/$script:resourceType"
        }
        It "Deployment should be successful" {
            $script:functionalTestDeploy.Value.ProvisioningState | Should -Be "Succeeded"
        }
        It "Resource properties sku should exist" {
            $script:fileContents.resources[0].properties.sku | Should -BeTrue
        }
        It "Resource properties publicNetworkAccess should exist" {
            $script:fileContents.resources[0].properties.publicNetworkAccess | Should -BeTrue
        }
        #endregion Pull Test

        #region Push Test
        It "Push should be successful" {
            $script:push.ProvisioningState | Should -Be "Succeeded"
        }
        #endregion Push Test
    }

    AfterAll {

    }

}