Describe "Function Test - Set-AzOpsRemoveOrder" {

    BeforeAll {

    }

    Context "Test: Set-AzOpsRemoveOrder Sorts as Expected" {
        It 'Sort based on priority' {
            InModuleScope AzOps {
                $storageAccount = 'storageAccount'
                $resourceGroups = 'resourceGroups'
                $locks = 'locks'
                $managementGroups = 'managementGroups'
                $routeTables = 'routeTables'
                $testList = @(
                    [PSCustomObject]@{
                        Name = 'Item1'
                        Type = $storageAccount
                    },
                    [PSCustomObject]@{
                        Name = 'Item2'
                        Type = $resourceGroups
                    },
                    [PSCustomObject]@{
                        Name = 'Item3'
                        Type = $locks
                    },
                    [PSCustomObject]@{
                        Name = 'Item4'
                        Type = $managementGroups
                    },
                    [PSCustomObject]@{
                        Name = 'Item5'
                        Type = $routeTables
                    }
                )
                $returnList = Set-AzOpsRemoveOrder -DeletionList $testList -Index { $_.Type }
                $returnList[0].Type | Should -Be $locks
                $returnList[1].Type | Should -Be $resourceGroups
                $returnList[2].Type | Should -Be $managementGroups
                $returnList[3].Type | Should -BeIn $storageAccount,$routeTables
                $returnList[4].Type | Should -BeIn $storageAccount,$routeTables
            }
        }
    }

    AfterAll {

    }

}