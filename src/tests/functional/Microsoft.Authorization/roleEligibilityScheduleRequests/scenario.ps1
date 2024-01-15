param (
    [Parameter(Mandatory = $true)]
    [array]
    $functionalTestFilePaths,
    [Parameter(Mandatory = $true)]
    [array]
    $functionalTestDeploy
)

Describe "Scenario - roleEligibilityScheduleRequests" {

    BeforeAll {
        $script:resourceProvider = (Resolve-Path $PSScriptRoot).Path.Split('/')[-2]
        $script:resourceType = (Resolve-Path $PSScriptRoot).Path.Split('/')[-1]
        $script:functionalTestDeploy = ($functionalTestDeploy | Where-Object {$_.functionalTestDeployJob -eq (($script:resourceType) + 'FunctionalTestDeploy')}).functionalTestDeploy

        #region Paths
        $script:path = ($functionalTestFilePaths | Where-Object Name -eq "$($script:resourceProvider)_$($script:resourceType)-$(($script:functionalTestDeploy.parameters.scheduleRequestName.value).toLower()).json")
        $script:directory = ($script:path).Directory
        $script:file = ($script:path).FullName
        $script:fileContents = Get-Content -Path $script:file -Raw | ConvertFrom-Json -Depth 25
        Write-PSFMessage -Level Debug -Message "TestResourcePath: $($script:file)" -FunctionName "Functional Tests"
        #endregion Paths

        #region Push Primer
        $changeSet = @(
            "A`t$script:file"
        )
        try {
            Write-PSFMessage -Level Debug -Message "Push Scenario $script:resourceType starting: $script:file" -FunctionName "Functional Tests"
            $script:push = Invoke-AzOpsPush -ChangeSet $changeSet -ErrorAction Stop
            Write-PSFMessage -Level Debug -Message "Push Scenario $script:resourceType completed: $script:file" -FunctionName "Functional Tests"
        }
        catch {
            if (($_.Exception.message).ToString() -like "*A role assignment request with Id: * already exists*") {
                $localpushtest = "Succeeded"
            }
            else {
                Write-PSFMessage -Level Critical -Message "Push Scenario $script:resourceType failed: $script:file" -Exception $_.Exception
            }
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
            $script:fileContents.resources[0].apiVersion | Should -Match '^\d{4}\-(0[1-9]|1[012])\-(0[1-9]|[12][0-9]|3[01])$'
        }
        It "Resource properties should exist" {
            $script:fileContents.resources[0].properties | Should -BeTrue
        }
        It "Resource type should match" {
            $script:fileContents.resources[0].type | Should -Be "$script:resourceProvider/$script:resourceType"
        }
        It "Deployment should be successful" {
            $script:functionalTestDeploy.ProvisioningState | Should -Be "Succeeded"
        }
        It "Resource properties RoleDefinitionId should exist" {
            $script:fileContents.resources[0].properties.RoleDefinitionId | Should -BeTrue
        }
        It "Resource properties PrincipalId should exist" {
            $script:fileContents.resources[0].properties.PrincipalId | Should -BeTrue
        }
        It "Resource properties ScheduleInfo StartDateTime should exist" {
            $script:fileContents.resources[0].properties.ScheduleInfo.StartDateTime | Should -BeTrue
        }
        It "Resource properties RequestType should exist" {
            $script:fileContents.resources[0].properties.RequestType | Should -BeTrue
        }
        #endregion Pull Test

        #region Push Test
        It "Push should be successful" {
            $localpushtest | Should -Be "Succeeded"
        }
        #endregion Push Test
    }

    AfterAll {

    }

}