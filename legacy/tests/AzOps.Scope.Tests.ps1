<#
    .SYNOPSIS
    Pester tests to validate the AzOpsScope class.

    .DESCRIPTION
    Pester tests to validate the AzOpsScope class.

    These tests validate functions within the AzOpsScope class:

     - AzOpsScope unit tests (-Tag "scope")

    Tests have been updated to use Pester version 5.0.x

    .EXAMPLE
    To run "Scope" tests only:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "scope"

    .EXAMPLE
    To run "Scope" tests only, and create test results for CI:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "scope" -CI

    .EXAMPLE
    To run "Scope", create test results for CI, and output detailed logs to host:

    PS C:\AzOps> Invoke-Pester -Path "./tests/" -TagFilter "scope" -CI -Output Detailed

    .INPUTS
    None

    .OUTPUTS
    None
#>

Describe "AzOpsScope (Unit Test)" -Tag "unit", "scope" {

    BeforeAll {

        # Import required modules
        Import-Module -Name ("$PSScriptRoot/../src/AzOps.psd1") -Force

        # Write-Verbose -Message "TestDrive: $TestDrive"

        # Task: Initialize environment variables
        $env:AZOPS_STATE = $TestDrive
        $env:AZOPS_INVALIDATE_CACHE = 1
        $env:AZOPS_IGNORE_CONTEXT_CHECK = 1

        $TenantID = (Get-AzContext).Tenant.Id

        # Initialize-AzOpsRepository
        Initialize-AzOpsRepository

        # Get random Management Group
        $mg = (Get-AzManagementGroup | Get-Random)
        # Get all ManagementGroup
        $pathToManagementGroup = ((Get-ChildItem -path $TestDrive -File -Recurse -Force | Where-Object { $_.Name -like "Microsoft.Management_managementGroups-*" })).Directory.Parent

        # Get all Subscriptions
        $subs = Get-AzSubscription -TenantId $TenantId -WarningAction SilentlyContinue
        # Get all subscriptions in the folder structure
        $pathToSubscriptions = ((Get-ChildItem -path $TestDrive -File -Recurse -Force | Where-Object { $_.Name -like "Microsoft.Subscription_subscriptions-*" })).Directory.Parent

        # Get all resource groups from all subscriptions with resource graph
        # $rgs = Get-AzSubscription | ForEach-Object -Process { Select-AzSubscription -SubscriptionId $_.Id | Out-Null ; Get-AzResourceGroup | Where-Object { -not($_.ManagedBy) } }
        # Get all resource groups in the folder structure
        # $pathToRgs = (((Get-ChildItem $TestDrive -Include resourcegroup.json -Recurse).Directory))

        $AzOpsScopeTest = @{ }
        $AzOpsScopeTest.Add("mg" , (New-AzOpsScope -scope $mg.Id))

        $pathToMg = $pathToManagementGroup | Get-Random

        $AzOpsScopeTest.Add("pathToMg" , (New-AzOpsScope -path $pathToMg.Fullname))

        $AzOpsScopeTest.Add("subs", $subs)

        $sub = ($subs | Get-Random)
        $AzOpsScopeTest.Add("sub", (New-AzOpsScope -scope "/subscriptions/$($sub.Id)" ))

        $pathToSubscription = $pathToSubscriptions | Get-Random
        $AzOpsScopeTest.Add("pathToSubscription", (New-AzOpsScope -path $pathToSubscription.Fullname))

        $AzOpsScopeTest.Add("rgs", $rgs)
        $AzOpsScopeTest.Add("rg", (New-AzOpsScope -scope ($rgs.resourceid | Get-Random)))

        # $AzOpsScopeTest.Add("rg", (New-AzOpsScope -scope '/subscriptions/66def07b-94b1-4262-8534-cfbcbe63631a/resourceGroups/Test'))

        # $AzOpsScopeTest.Add("pathToResourceGroup" , (New-AzOpsScope -path (((Get-ChildItem $TestDrive -Include resourcegroup.json -Recurse) | Get-Random).Directory.Fullname)))
        # $AzOpsScopeTest.Add("pathToResourceGroupAzState" , (New-AzOpsScope -path (join-path ((Get-ChildItem $TestDrive -Include resourcegroup.json -Recurse) | get-random ).Directory.Fullname -ChildPath '.AzState' )  ))

        # $AzOpsScopeTest.Add("resource", (New-AzOpsScope -scope (Get-AzResource | Get-Random).Id))
        # $AzOpsScopeTest.Add("invalidFileNameResource", (New-AzOpsScope -scope('')))
        # $AzOpsScopeTest.Add("pathToResource", (New-AzOpsScope -path ($AzOpsScopeTest.resource.statepath)))

        # $policyAssignmentId = (Get-AzPolicyAssignment -WarningAction SilentlyContinue | Get-Random).Id
        # $AzOpsScopeTest.Add("policyAssignment", (New-AzOpsScope -scope $policyAssignmentId))

        $policyDefinitionId = (Get-AzPolicyDefinition -WarningAction SilentlyContinue -Custom -ManagementGroupName Contoso | Get-Random).ResourceId
        # $policyDefinitionId = '/providers/Microsoft.Management/managementGroups/Tailspin/providers/Microsoft.Authorization/policyDefinitions/DINE-KeyVault'
        $AzOpsScopeTest.Add("policyDefinition", (New-AzOpsScope -scope $policyDefinitionId))

        $policySetDefinitionId = (Get-AzPolicySetDefinition -Custom -WarningAction SilentlyContinue -ManagementGroupName Contoso | Get-Random).ResourceId
        $AzOpsScopeTest.Add("policySetDefinition", (New-AzOpsScope -scope $policySetDefinitionId))
    }

    Context 'AzOpsScope' {

        It "Management Group should not be null or empty" {
            $AzOpsScopeTest.mg | Should -Not -BeNullOrEmpty
        }
        It "Management Group Type should be  managementGroup" {
            $AzOpsScopeTest.mg.type | Should -MatchExactly "managementGroups"
        }
        It "Management Group of managementgroup should match" {
            $AzOpsScopeTest.mg.managementgroup | Should -MatchExactly $mg.managementgroup
        }
        It "Management Group of managementgroupDisplayName should match" {
            $AzOpsScopeTest.mg.managementgroupDisplayName | Should -MatchExactly $mg.managementgroupDisplayName
        }
        It "Management Group Name should match" {
            $AzOpsScopeTest.mg.name | Should -MatchExactly $($AzOpsScopeTest.mg.scope.split('/') | Select-Object -last 1)
        }
        It "Management Group StatePath should Match  Microsoft.Management_managementGroups-$($AzOpsScopeTest.mg.name).parameters.json" {
            $AzOpsScopeTest.mg.statepath | Should -Match "Microsoft.Management_managementGroups-$($AzOpsScopeTest.mg.name).parameters.json"
        }

        It "Path to Management Group should not be null or empty" {
            $AzOpsScopeTest.pathToMg | Should -Not -BeNullOrEmpty
        }
        It "Path to Management Group Type should be  managementGroup" {
            $AzOpsScopeTest.pathToMg.type | Should -MatchExactly "managementGroups"
        }
        It "Path to Management Group of ManagementgroupDisplayName should match" {
            "$($AzOpsScopeTest.pathToMg.managementgroupDisplayName) ($($AzOpsScopeTest.pathToMg.managementgroup))" | Should -BeExactly $pathToMg.Name
        }
        It "Path to Management Group Name should match" {
            $AzOpsScopeTest.pathToMg.name | Should -MatchExactly $($AzOpsScopeTest.pathToMg.scope.split('/') | Select-Object -last 1)
        }
        It "Path to Management Group of StatePath should Match Microsoft.Management_managementGroups-$($AzOpsScopeTest.pathToMg.name).parameters.json" {
            $AzOpsScopeTest.pathToMg.statepath | Should -Match  "Microsoft.Management_managementGroups-$($AzOpsScopeTest.pathToMg.name).parameters.json"
        }

        It "Subscription should not be null or empty" {
            $AzOpsScopeTest.sub | Should -Not -BeNullOrEmpty
        }
        It "Subscription of Subscription should not be null or empty" {
            $AzOpsScopeTest.sub | Should -Not -BeNullOrEmpty
        }
        It "Subscription of SubscriptionType should be  subscriptions" {
            $AzOpsScopeTest.sub.managementgroup | Should -Not -BeNullOrEmpty
        }
        It "Subscription of Subscription Name should match" {
            $AzOpsScopeTest.sub.name | Should -MatchExactly $($sub.Id)
        }
        It "Subscription of Subscription property  should match" {
            $AzOpsScopeTest.sub.subscription | Should -MatchExactly $($sub.Id)
        }
        It "Subscription of StatePath should Match with Microsoft.Subscription_subscriptions-$($AzOpsScopeTest.sub.subscription).parameters.json" {
            $AzOpsScopeTest.sub.statepath | Should -Match "Microsoft.Subscription_subscriptions-$($AzOpsScopeTest.sub.subscription).parameters.json"
        }
        It "Subscription count from platform should match number of subscription.json" {
            $AzOpsScopeTest.subs.Count | Should -BeExactly $pathToSubscriptions.Count
        }

        It "Path to Subscription should not be null or empty" {
            $AzOpsScopeTest.pathToSubscription | Should -Not -BeNullOrEmpty
        }
        It "Path to Subscription of managementgroup should not be null or empty" {
            $AzOpsScopeTest.pathToSubscription | Should -Not -BeNullOrEmpty
        }
        It "Path to Subscription of SubscriptionType should be subscriptions" {
            $AzOpsScopeTest.pathToSubscription.managementgroup | Should -Not -BeNullOrEmpty
        }
        It "Path to Subscription of Subscription Name should match" {
            $AzOpsScopeTest.pathToSubscription.name | Should -MatchExactly $($AzOpsScopeTest.pathToSubscription.scope.split('/') | Select-Object -last 1)
        }
        It "Path to Subscription of Subscription should match" {
            $AzOpsScopeTest.pathToSubscription.subscription | Should -MatchExactly $pathToSubscription.Subscription
        }
        It "Path to Subscription of subscriptionDisplayName should match" {
            # Since everything is under .AzState we are checking parent directory name for displayname
            "$($AzOpsScopeTest.pathToSubscription.subscriptionDisplayName) ($($AzOpsScopeTest.pathToSubscription.subscription))" | Should -BeExactly $pathToSubscription.Name
        }
        It "Path to Subscription of StatePath should Match Microsoft.Subscription_subscriptions-$($AzOpsScopeTest.pathToSubscription.subscription).parameters.json" {
            $AzOpsScopeTest.pathToSubscription.statepath | Should -Match "Microsoft.Subscription_subscriptions-$($AzOpsScopeTest.pathToSubscription.subscription).parameters.json"
        }

        <#
        It "Resourcegroup count from platform should match number of resourcegroup.json" {
            $AzOpsScopeTest.rgs.count | Should -BeExactly $pathToRgs.Count
        }
        It "Resourcegroup of Resourcegroup should not be null or empty" {
            $AzOpsScopeTest.rg | Should -Not -BeNullOrEmpty
        }
        It "Resourcegroup of Resourcegroup.Type should be resourcegroups" {
            $AzOpsScopeTest.rg.type | Should -MatchExactly "resourcegroups"
        }
        It "Resourcegroup of SubscriptionType should be subscriptions" {
            $AzOpsScopeTest.rg.managementgroup | Should -Not -BeNullOrEmpty
        }
        It "Resourcegroup of Resourcegroup Name should match" {
            $AzOpsScopeTest.rg.name | Should -MatchExactly $($AzOpsScopeTest.rg.scope.split('/') | Select-Object -last 1)
        }

        It "Resourcegroup of Resourcegroup should match" {
            $AzOpsScopeTest.rg.Resourcegroup | Should -MatchExactly $($AzOpsScopeTest.rg.scope.split('/') | Select-Object -last 1)
        }
        It "Resourcegroup of StatePath should end with resourcegroup.json" {
            $AzOpsScopeTest.rg.statepath | Should -Match "resourcegroup.json"
        }
        It "Resourcegroup of Subscription should match" {
            $AzOpsScopeTest.rg.subscription | Should -MatchExactly $((get-Azsubscription -WarningAction Ignore -SubscriptionId $($AzOpsScopeTest.rg.scope.split('/')[2])).Name)
        }
        #>

        # It "Path to Resourcegroup should not be null or empty" {
        #     $AzOpsScopeTest.pathToResourceGroup | Should -Not -BeNullOrEmpty
        # }
        # It "Path to Resourcegroup of Resourcegroup.Type should be  resourcegroups" {
        #     $AzOpsScopeTest.pathToResourceGroup.type | Should -MatchExactly "resourcegroups"
        # }
        # It "Path to Resourcegroup of SubscriptionType should be  subscriptions" {
        #     $AzOpsScopeTest.pathToResourceGroup.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Path to Resourcegroup of  Resourcegroup  Name should match" {
        #     $AzOpsScopeTest.pathToResourceGroup.name | Should -MatchExactly $($AzOpsScopeTest.pathToResourceGroup.scope.split('/') | select -last 1)
        # }
        # It "Path to Resourcegroup of Subscription should match" {
        #     $AzOpsScopeTest.pathToResourceGroup.subscription | Should -MatchExactly $((Get-AzSubscription -subscriptionId ($AzOpsScopeTest.pathToResourceGroup.scope.split('/')[2])).Name)
        # }
        # It "Path to Resourcegroup of Resourcegroup should match name" {
        #     $AzOpsScopeTest.pathToResourceGroup.Resourcegroup | Should -MatchExactly $($AzOpsScopeTest.pathToResourceGroup.scope.split('/') | select -last 1)
        # }
        # It "Path to Resourcegroup of StatePath should end with resourcegroup.json" {
        #     $AzOpsScopeTest.pathToResourceGroup.statepath | Should -Match  "resourcegroup.json"
        # }

        # It "Path to ResourceGroup AzState of Resourcegroup should not be null or empty" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState | Should -Not -BeNullOrEmpty
        # }
        # It "Path to ResourceGroup AzState of Resourcegroup.Type should be  resourcegroups" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.type | Should -MatchExactly "resourcegroups"
        # }
        # It "Path to ResourceGroup AzState of SubscriptionType should be  subscriptions" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Path to ResourceGroup AzState of Resourcegroup  Name should match" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.name | Should -MatchExactly $( $AzOpsScopeTest.pathToResourceGroupAzState.scope.split('/') | select -last 1)
        # }
        # It "Path to ResourceGroup AzState of Subscription should match" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.subscription | Should -MatchExactly  $((Get-AzSubscription -subscriptionId $AzOpsScopeTest.pathToResourceGroupAzState.scope.split('/')[2]).Name)
        # }
        # It "Path to ResourceGroup AzState of Resourcegroup should match" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.Resourcegroup | Should -MatchExactly $( $AzOpsScopeTest.pathToResourceGroupAzState.scope.split('/') | select -last 1)
        # }
        # It "Path to ResourceGroup AzState of StatePath should end with resourcegroup.json" {
        #     $AzOpsScopeTest.pathToResourceGroupAzState.statepath | Should -Match  "resourcegroup.json"
        # }

        # It "Resource of Resourcegroup should not be null or empty" {
        #     $AzOpsScopeTest.resource | Should -Not -BeNullOrEmpty
        # }
        # It "Resource of managementgroup should not be null or empty" {
        #     $AzOpsScopeTest.resource.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Resource of resource.type should be  resource" {
        #     $AzOpsScopeTest.resource.type | Should -MatchExactly "resource"
        # }
        # It "Resource of Resource  Name should match" {
        #     $AzOpsScopeTest.resource.name | Should -MatchExactly $( $AzOpsScopeTest.resource.scope.split('/') | select -last 1)
        # }
        # It "Resource of  Subscription should match" {
        #     $AzOpsScopeTest.resource.subscription | Should -MatchExactly $((Get-AzSubscription -subscriptionId  $AzOpsScopeTest.resource.scope.split('/')[2]).Name)
        # }
        # It "Resource of Resource Provider should match" {
        #     $AzOpsScopeTest.resource.resourceprovider | Should -Match $( $AzOpsScopeTest.resource.scope.split('/')[6])
        # }
        # It "Resource of Resource should match" {
        #     $AzOpsScopeTest.resource.resource | Should -MatchExactly $( $AzOpsScopeTest.resource.scope.split('/')[7])
        # }
        # It "Resource of StatePath should contain Management Group" {
        #     $AzOpsScopeTest.resource.statepath | Should -Match  $AzOpsScopeTest.resource.managementgroup
        # }
        # It "Resource of StatePath should contain Subscription group" {
        #     $AzOpsScopeTest.resource.statepath | Should -Match  $AzOpsScopeTest.resource.subscription
        # }
        # It "Resource of StatePath should contain resource provider" {
        #     $AzOpsScopeTest.resource.statepath | Should -Match  $AzOpsScopeTest.resource.resourceprovider
        # }
        # It "Resource of StatePath should contain resource" {
        #     $AzOpsScopeTest.resource.statepath | Should -Match  $AzOpsScopeTest.resource.resource
        # }
        # It "Resource of StatePath should contain resource name" {
        #     $AzOpsScopeTest.resource.statepath | Should -Match $( $AzOpsScopeTest.resource.name + ".json")
        # }

        # It "Long Resource Name should not be null or empty" {
        #     $AzOpsScopeTest.invalidFileNameResource | Should -Not -BeNullOrEmpty
        # }
        # It "Long Resource Name's managementgroup should not be null or empty" {
        #     $AzOpsScopeTest.invalidFileNameResource.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Long Resource Name's resource.type should be  resource" {
        #     $AzOpsScopeTest.invalidFileNameResource.type | Should -MatchExactly "resource"
        # }
        # It "Long Resource Name's Subscription should match" {
        #     $AzOpsScopeTest.invalidFileNameResource.subscription | Should -MatchExactly $((Get-AzSubscription -subscriptionId  $AzOpsScopeTest.invalidFileNameResource.scope.split('/')[2]).Name)
        # }
        # It "Long Resource Name's Resource Provider should match" {
        #     $AzOpsScopeTest.invalidFileNameResource.resourceprovider | Should -Match $( $AzOpsScopeTest.invalidFileNameResource.scope.split('/')[6])
        # }
        # It "Long Resource Name's Resource should match" {
        #     $AzOpsScopeTest.invalidFileNameResource.resource | Should -MatchExactly $( $AzOpsScopeTest.invalidFileNameResource.scope.split('/')[7])
        # }
        # It "Long Resource Name's StatePath should contain Management Group" {
        #     $AzOpsScopeTest.invalidFileNameResource.statepath | Should -Match  $AzOpsScopeTest.invalidFileNameResource.managementgroup
        # }
        # It "Long Resource Name's StatePath should contain Subscription" {
        #     $AzOpsScopeTest.invalidFileNameResource.statepath | Should -Match  $AzOpsScopeTest.invalidFileNameResource.subscription
        # }
        # It "Long Resource Name's StatePath should contain resource group" {
        #     $AzOpsScopeTest.invalidFileNameResource.Resourcegroup | Should -Match  $AzOpsScopeTest.invalidFileNameResource.resourcegroup
        # }
        <#
        It "StatePath should contain resource name" {
            $stream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($( $AzOpsScopeTest.invalidFileNameResource.scope.split('/') | select -last 1)))
            $hash = $((Get-FileHash -InputStream $stream -Algorithm MD5).Hash)
            $AzOpsScopeTest.invalidFileNameResource.statepath | Should -Match $hash
        }
        #>


        # It "Management Group Policy Assignment should not be null or empty" {
        #     $AzOpsScopeTest.policyAssignment | Should -Not -BeNullOrEmpty
        # }
        # It "Management Group Policy Assignment of managementgroup should not be null or empty" {
        #     $AzOpsScopeTest.policyAssignment.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Management Group Policy Assignment of resource.type should be  resource" {
        #     $AzOpsScopeTest.policyAssignment.type | Should -MatchExactly "resource"
        # }
        # It "Management Group Policy Assignment of Resource  Name should match" {
        #     $AzOpsScopeTest.policyAssignment.name | Should -MatchExactly $($AzOpsScopeTest.policyAssignment.scope.split('/') | select -last 1)
        # }
        # It "Management Group Policy Assignment of Subscription should be null or empty" {

        #     $AzOpsScopeTest.policyAssignment.subscription | Should -BeNullOrEmpty
        # }
        # It "Management Group Policy Assignment of resourcegroup should be null or empty" {
        #     $AzOpsScopeTest.policyAssignment.resourcegroup | Should -BeNullOrEmpty
        # }
        # It "Management Group Policy Assignment of Resource Provider should match" {
        #     $AzOpsScopeTest.policyAssignment.resourceprovider | Should -Match $($AzOpsScopeTest.policyAssignment.scope.split('/')[6])
        # }
        # It "Management Group Policy Assignment of Resource should match" {
        #     $AzOpsScopeTest.policyAssignment.resource | Should -MatchExactly $($AzOpsScopeTest.policyAssignment.scope.split('/')[7])
        # }
        # It "Management Group Policy Assignment of StatePath should contain Management Group" {
        #     $AzOpsScopeTest.policyAssignment.statepath | Should -Match $AzOpsScopeTest.policyAssignment.managementgroup
        # }
        # It "Management Group Policy Assignment of StatePath should contain resource provider" {
        #     $AzOpsScopeTest.policyAssignment.statepath | Should -Match $AzOpsScopeTest.policyAssignment.resourceprovider
        # }
        # It "Management Group Policy Assignment of StatePath should contain resource" {
        #     $AzOpsScopeTest.policyAssignment.statepath | Should -Match $AzOpsScopeTest.policyAssignment.resource
        # }
        # It "Management Group Policy Assignment of StatePath should contain resource name" {
        #     $AzOpsScopeTest.policyAssignment.statepath | Should -Match $($AzOpsScopeTest.policyAssignment.name + ".json")
        # }

        It "Management Group Policy Definition should not be null or empty" {
            $AzOpsScopeTest.policyDefinition | Should -Not -BeNullOrEmpty
        }
        It "Management Group Policy Definition managementgroup should not be null or empty" {
            $AzOpsScopeTest.policyDefinition.managementgroup | Should -Not -BeNullOrEmpty
        }
        It "Management Group Policy Definition  resource.type should be  resource" {
            $AzOpsScopeTest.policyDefinition.type | Should -MatchExactly "resource"
        }
        It "Management Group Policy Definition Resource Name should match" {
            $AzOpsScopeTest.policyDefinition.name | Should -MatchExactly $( $AzOpsScopeTest.policyDefinition.scope.split('/') | Select-Object -last 1)
        }
        It "Management Group Policy Definition Subscription should be null or empty" {
            $AzOpsScopeTest.policyDefinition.subscription | Should -BeNullOrEmpty
        }
        It "Management Group Policy Definition resourcegroup should be null or empty" {
            $AzOpsScopeTest.policyDefinition.resourcegroup | Should -BeNullOrEmpty
        }
        It "Management Group Policy Definition Resource Provider should match" {
            $AzOpsScopeTest.policyDefinition.resourceprovider | Should -Match $( $AzOpsScopeTest.policyDefinition.scope.split('/')[6])
        }
        It "Management Group Policy Definition Resource should match" {
            $AzOpsScopeTest.policyDefinition.resource | Should -MatchExactly $( $AzOpsScopeTest.policyDefinition.scope.split('/')[7])
        }
        It "Management Group Policy Definition StatePath should contain Management Group" {
            $AzOpsScopeTest.policyDefinition.statepath | Should -Match  $AzOpsScopeTest.policyDefinition.managementgroup
        }
        It "Management Group Policy Definition StatePath should contain resource provider" {
            $AzOpsScopeTest.policyDefinition.statepath | Should -Match  $AzOpsScopeTest.policyDefinition.resourceprovider
        }
        It "Management Group Policy Definition StatePath should contain resource" {
            $AzOpsScopeTest.policyDefinition.statepath | Should -Match  $AzOpsScopeTest.policyDefinition.resource
        }
        It "Management Group Policy Definition StatePath should contain resource name" {
            $AzOpsScopeTest.policyDefinition.statepath | Should -Match $( $AzOpsScopeTest.policyDefinition.name + ".parameters.json")
        }

        # It "Subscripion PolicySet Definition should not be null or empty" {
        #     $AzOpsScopeTest.policySetDefinition | Should -Not -BeNullOrEmpty
        # }
        # It "Subscripion PolicySet Definition of managementgroup should not be null or empty" {
        #     $AzOpsScopeTest.policySetDefinition.managementgroup | Should -Not -BeNullOrEmpty
        # }
        # It "Subscripion PolicySet Definition of resource.type should be  resource" {
        #     $AzOpsScopeTest.policySetDefinition.type | Should -MatchExactly "resource"
        # }
        # It "Subscripion PolicySet Definition of Resource  Name should match" {
        #     $AzOpsScopeTest.policySetDefinition.name | Should -MatchExactly $( $AzOpsScopeTest.policySetDefinition.scope.split('/') | select -last 1)
        # }
        # It "Subscripion PolicySet Definition of Subscription should match" {
        #     $AzOpsScopeTest.policySetDefinition.subscription | Should -MatchExactly $((Get-AzSubscription -subscriptionId $AzOpsScopeTest.policySetDefinition.scope.split('/')[2]).Name)
        # }
        # It "Subscripion PolicySet Definition of resourcegroup should be null or empty" {
        #     $AzOpsScopeTest.policySetDefinition.resourcegroup | Should -BeNullOrEmpty
        # }
        # It "Subscripion PolicySet Definition of Resource Provider should match" {
        #     $AzOpsScopeTest.policySetDefinition.resourceprovider | Should -Match $( $AzOpsScopeTest.policySetDefinition.scope.split('/')[4])
        # }
        # It "Subscripion PolicySet Definition of Resource should match" {
        #     $AzOpsScopeTest.policySetDefinition.resource | Should -MatchExactly $( $AzOpsScopeTest.policySetDefinition.scope.split('/')[5])
        # }
        # It "Subscripion PolicySet Definition of StatePath should contain Management Group" {
        #     $AzOpsScopeTest.policySetDefinition.statepath | Should -Match  $AzOpsScopeTest.policySetDefinition.managementgroup
        # }
        # It "Subscripion PolicySet Definition of StatePath should contain resource provider" {
        #     $AzOpsScopeTest.policySetDefinition.statepath | Should -Match  $AzOpsScopeTest.policySetDefinition.resourceprovider
        # }
        # It "Subscripion PolicySet Definition of StatePath should contain resource" {
        #     $AzOpsScopeTest.policySetDefinition.statepath | Should -Match  $AzOpsScopeTest.policySetDefinition.resource
        # }
        # It "Subscripion PolicySet Definition of StatePath should contain resource name" {
        #     $AzOpsScopeTest.policySetDefinition.statepath | Should -Match $( $AzOpsScopeTest.policySetDefinition.name + ".json")
        # }
    }

}
