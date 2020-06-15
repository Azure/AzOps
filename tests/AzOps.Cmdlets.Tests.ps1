#Import required modules
Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force
Get-ChildItem "$PSScriptRoot/../src/private" -Force | ForEach-Object -Process { . $_.FullName }
#Set required variables
$env:AzOpsState = $TestDrive
$env:InvalidateCache = 1
$env:AzOpsMasterTemplate = ("$PSScriptRoot/../src/template.json")
$env:AzOpsStateConfig = ("$PSScriptRoot/../src/AzOpsStateConfig.json")
Initialize-AzOpsGlobalVariables
InModuleScope 'AzOps' {

    #region Public
    <#
    Describe "Initialize-AzOpsGlobalVariables" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Initialize-AzOpsRepository" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Invoke-AzOpsGitPull" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Invoke-AzOpsGitPush" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }
    #endregion

    #region Private
    Describe "Compare-AzOpsState" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }
    #>
    Describe "ConvertTo-AzOpsObject" {

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

        Context "Validate outputs" {
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

        AfterAll { }

    }

    Describe "ConvertTo-AzOpsState" {

        BeforeAll {
            #Get Resources
            $policyDefinition = Get-AzPolicyDefinition -Custom | Get-Random
            $policyAssignment = Get-AzPolicyAssignment | Get-Random
            $policySetDefinition = Get-AzPolicySetDefinition -Custom | Get-Random
            $resourceGroup = Get-AzResourceGroup | Get-Random
        }

        Context "Validate outputs" {
            #Validate default exclusion of properties - metadata should always be excluded for policy objects
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

        AfterAll { }

    }

    Describe "Test-AzOpsDuplicateSubMgmtGroup" {

        BeforeAll {
            #Mock subscription object
            $Subscriptions = 1..3 | ForEach-Object -Process { [pscustomobject]@{ Name = "Subscription 1" ; Id = New-Guid } }
            #Mock managementgroup object
            $ManagementGroups = 1..3  | ForEach-Object -Process { [pscustomobject]@{ DisplayName = "Management Group 1" ; Id = New-Guid } }

            #Test cmdlet against mock data to return output
            $DuplicateTest = Test-AzOpsDuplicateSubMgmtGroup -Subscriptions $Subscriptions -ManagementGroups $ManagementGroups
            #Test cmdlet against inputdata with 1 subscription/management group
            $SingleTest = Test-AzOpsDuplicateSubMgmtGroup -Subscription ($Subscriptions | Select-Object -First 1) -ManagementGroups ($ManagementGroups | Select-Object -First 1)
        }

        Context "Validate outputs" {

            It "Passes returns 3 management groups with duplicate names" {
                ($DuplicateTest | Where-Object { $_.Type -eq "ManagementGroup" }).Count | Should -BeExactly 3
            }
            It "Passes returns 3 subscriptions with duplicate names" {
                ($DuplicateTest | Where-Object { $_.Type -eq "Subscription" }).Count | Should -BeExactly 3
            }
            It "Passes returns null when no duplicate subscriptions or management groups found" {
                $SingleTest | Should -BeNullOrEmpty
            }

        }

        AfterAll { }

    }
    <#
    Describe "ConvertTo-TemplateParameterObject" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsAllChildrenInManagementGroup" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsAllManagementGroup" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsGitBranch" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsGitStatus" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsPolicyAssignmentAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsPolicyDefinitionAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsPolicySetDefinitionAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsResourceDefinitionAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsRoleAssignmentAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsRoleDefinitionAtScope" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Get-AzOpsStateForManagementGroupsAndSubscriptions" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Invoke-AzOpsGitRefresh" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Invoke-AzOpsPolicyEvaluation" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "New-AzMgmtGroupDeployment" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "New-AzOpsComment" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "New-AzOpsPullRequest" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "New-AzOpsStateDeployment" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Register-AzOpsProviderFeature" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Register-AzOpsResourceProvider" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Remove-AzOpsManagementGroup" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }

    Describe "Save-AzOpsManagementGroupState" {

        BeforeAll { }

        Context { }

        AfterAll { }

    }
    #>
    #endregion

}