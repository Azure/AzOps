class AzOpsScope {

    [string]$Scope
    [string]$Type
    [string]$Name
    [string]$StatePath
    [string]$ManagementGroup
    [string]$ManagementGroupDisplayName
    [string]$Subscription
    [string]$SubscriptionDisplayName
    [string]$ResourceGroup
    [string]$ResourceProvider
    [string]$Resource

    hidden [string]$StateRoot

    #region Internal Regex Helpers
    hidden [regex]$regex_tenant = '/$'
    hidden [regex]$regex_managementgroup = '(?i)^/providers/Microsoft.Management/managementgroups/[^/]+$'
    hidden [regex]$regex_managementgroupExtract = '(?i)^/providers/Microsoft.Management/managementgroups/'

    hidden [regex]$regex_subscription = '(?i)^/subscriptions/[^/]*$'
    hidden [regex]$regex_subscriptionExtract = '(?i)^/subscriptions/'

    hidden [regex]$regex_resourceGroup = '(?i)^/subscriptions/.*/resourcegroups/[^/]*$'
    hidden [regex]$regex_resourceGroupExtract = '(?i)^/subscriptions/.*/resourcegroups/'

    hidden [regex]$regex_managementgroupProvider = '(?i)^/providers/Microsoft.Management/managementgroups/[\s\S]*/providers'
    hidden [regex]$regex_subscriptionProvider = '(?i)^/subscriptions/.*/providers'
    hidden [regex]$regex_resourceGroupProvider = '(?i)^/subscriptions/.*/resourcegroups/[\s\S]*/providers'

    hidden [regex]$regex_managementgroupResource = '(?i)^/providers/Microsoft.Management/managementGroups/[\s\S]*/providers/[\s\S]*/[\s\S]*/'
    hidden [regex]$regex_subscriptionResource = '(?i)^/subscriptions/.*/providers/[\s\S]*/[\s\S]*/'
    hidden [regex]$regex_resourceGroupResource = '(?i)^/subscriptions/.*/resourcegroups/[\s\S]*/providers/[\s\S]*/[\s\S]*/'
    #endregion Internal Regex Helpers

    #region Constructors
    AzOpsScope ([string]$Scope, [string]$StateRoot) {
    <#
        .SYNOPSIS
            Creates an AzOpsScope based on the specified resource ID

        .DESCRIPTION
            Creates an AzOpsScope based on the specified resource ID

        .PARAMETER Scope
            Scope == ResourceID

        .INPUTS
            None. You cannot pipe objects to Add-Extension.

        .OUTPUTS
            System.String. Add-Extension returns a string with the extension or file name.

        .EXAMPLE
            New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"

            Creates an AzOpsScope based on the specified resource ID
    #>
        $this.StateRoot = $StateRoot
        $this.InitializeMemberVariables($Scope)
    }

    # Overloaded constructors -  repeat member assignments in each constructor definition
    AzOpsScope ([System.IO.DirectoryInfo]$Path, [string]$StateRoot) {
        $this.StateRoot = $StateRoot
        $this.InitializeMemberVariablesFromPath($Path)
    }

    AzOpsScope ([System.IO.FileInfo]$Path, [string]$StateRoot) {
        if (-not $Path.Exists) { throw 'Invalid Input!' }
        $this.StateRoot = $StateRoot

        if ($Path.Extension -ne '.json') {
            # Try to determine based on directory
            $this.InitializeMemberVariablesFromPath($Path.Directory)
            return
        }

        $resourcepath = Get-Content $Path | ConvertFrom-Json -AsHashtable

        if (
            $resourcepath -and
            $resourcepath.Keys -contains '$schema' -and
            $resourcepath.Keys -contains 'parameters' -and
            $resourcepath.parameters.Keys -contains 'input'
        ) {
            #region Schema Example
                    <#
                        {
                            "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                            "contentVersion": "1.0.0.0",
                            "parameters": {
                                "input": {
                                    "value": {
                                        "Id": "/providers/Microsoft.Management/managementGroups/contoso"
                                    }
                                }
                            }
                        }
                    #>
            #endregion Schema Example

            if ($resourcepath.parameters.input.value.Keys -contains "ResourceId") {
                # Resource
                $this.InitializeMemberVariables($resourcepath.parameters.input.value.ResourceId)
            }
            elseif ($resourcepath.parameters.input.value.Keys -contains "Id") {
                # ManagementGroup and Subscription
                $this.InitializeMemberVariables($resourcepath.parameters.input.value.Id)
            }
            else {
                # Try to determine based on directory
                $this.InitializeMemberVariablesFromPath($Path.Directory)
            }
        }
        else {
            # Try to determine based on directory
            $this.InitializeMemberVariablesFromPath($Path.Directory)
        }
    }
    #endregion Constructors

    #region Initializers
    hidden [void] InitializeMemberVariablesFromPath([System.IO.DirectoryInfo]$Path) {

        if ($Path.FullName -eq (Get-Item $this.StateRoot).FullName) {
            # Root tenant path
            $this.InitializeMemberVariables("/")
            return
        }

        # Always look into .AzState folder regardless of path specified
        if ($Path.FullName -notlike '*.azstate') {
            $Path = Join-Path $Path -ChildPath '.AzState'
        }
        $managementGroupFileName = "Microsoft.Management_managementGroups-*.parameters.json"
        $subscriptionFileName = "Microsoft.Subscription_subscriptions-*.parameters.json"
        $resourceGroupFileName = "Microsoft.Resources_resourceGroups-*.parameters.json"

        if ($children = Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $managementGroupFileName) {
            $managementGroupConfig = Get-Content -Path $children.FullName | ConvertFrom-Json
            if ($managementGroupConfig.parameters.input.value.Id) {
                $this.InitializeMemberVariables($managementGroupConfig.parameters.input.value.Id)
            }
            else {
                Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.Input.BadData.ManagementGroup' -StringValues ($children.FullName -join ', ') -FunctionName AzOpsScope -ModuleName AzOps
                throw "Invalid Management Group Data! Validate integrity of $($children.FullName -join ', ')"
            }
        }
        elseif ($children = Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $subscriptionFileName) {
            $subscriptionConfig = Get-Content -Path $children.FullName | ConvertFrom-Json
            if ($subscriptionConfig.parameters.input.value.Id) {
                $this.InitializeMemberVariables($subscriptionConfig.parameters.input.value.Id)
            }
            else {
                Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.Input.BadData.Subscription' -StringValues ($children.FullName -join ', ') -FunctionName AzOpsScope -ModuleName AzOps
                throw "Invalid Subscription Data! Validate integrity of $($children.FullName -join ', ')"
            }
        }
        elseif ($children = Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $resourceGroupFileName) {
            $resourceGroupConfig = Get-Content -Path $children.FullName | ConvertFrom-Json
            if ($resourceGroupConfig.parameters.input.value.ResourceId) {
                $this.InitializeMemberVariables($resourceGroupConfig.parameters.input.value.ResourceId)
            }
            else {
                Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.Input.BadData.ResourceGroup' -StringValues ($children.FullName -join ', ') -FunctionName AzOpsScope -ModuleName AzOps
                throw "Invalid Resource Group Data! Validate integrity of $($children.FullName -join ', ')"
            }
        }
        else {
            Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.Input.BadData.UnknownType' -StringValues $Path -FunctionName AzOpsScope -ModuleName AzOps
            throw "Invalid File Structure! Cannot find Management Group / Subscription / Resource Group files in $Path!"
        }
    }
    hidden [void] InitializeMemberVariables([string]$Scope) {
        $this.Scope = $Scope

        if ($this.IsResource()) {
            $this.Type = "resource"
            $this.Name = $this.IsResource()
            $this.Subscription = $this.GetSubscription()
            $this.SubscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.ManagementGroup = $this.GetManagementGroup()
            $this.ManagementGroupDisplayName = $this.GetManagementGroupName()
            $this.ResourceGroup = $this.GetResourceGroup()
            $this.ResourceProvider = $this.IsResourceProvider()
            $this.Resource = $this.GetResource()
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = $this.GetAzOpsResourcePath() + ".json"
            }
            else {
                $this.StatePath = $this.GetAzOpsResourcePath() + ".parameters.json"
            }
        }
        elseif ($this.IsResourceGroup()) {
            $this.Type = "resourcegroups"
            $this.Name = $this.IsResourceGroup()
            $this.Subscription = $this.GetSubscription()
            $this.SubscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.ManagementGroup = $this.GetManagementGroup()
            $this.ManagementGroupDisplayName = $this.GetManagementGroupName()
            $this.ResourceGroup = $this.GetResourceGroup()
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources_resourceGroups-$($this.ResourceGroup).json")
            }
            else {
                $this.StatePath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources_resourceGroups-$($this.ResourceGroup).parameters.json")
            }
        }
        elseif ($this.IsSubscription()) {
            $this.Type = "subscriptions"
            $this.Name = $this.IsSubscription()
            $this.Subscription = $this.GetSubscription()
            $this.SubscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.ManagementGroup = $this.GetManagementGroup()
            $this.ManagementGroupDisplayName = $this.GetManagementGroupName()
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription_subscriptions-$($this.Subscription).json")
            }
            else {
                $this.StatePath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription_subscriptions-$($this.Subscription).parameters.json")
            }

        }
        elseif ($this.IsManagementGroup()) {
            $this.Type = "managementGroups"
            $this.Name = $this.GetManagementGroup()
            $this.ManagementGroup = ($this.GetManagementGroup()).Trim()
            $this.ManagementGroupDisplayName = ($this.GetManagementGroupName()).Trim()
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (join-path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath ".AzState\Microsoft.Management_managementGroups-$($this.ManagementGroup).json")
            }
            else {
                $this.StatePath = (join-path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath ".AzState\Microsoft.Management_managementGroups-$($this.ManagementGroup).parameters.json")
            }
        }
        elseif ($this.IsRoot()) {
            $this.Type = "root"
            $this.Name = "/"
            $this.StatePath = $this.StateRoot
        }
    }
    #endregion Initializers

    [String] ToString() {
        return $this.Scope
    }

    #region Validators
    [bool] IsRoot() {
        if (($this.Scope -match $this.regex_tenant)) {
            return $true
        }
        return $false
    }
    [bool] IsManagementGroup() {
        if (($this.Scope -match $this.regex_managementgroup)) {
            return $true
        }
        return $false
    }

    [string] IsSubscription() {
        if (($this.Scope -match $this.regex_subscription)) {
            return ($this.Scope.Split('/')[2])
        }
        return $null
    }
    [string] IsResourceGroup() {
        if (($this.Scope -match $this.regex_resourceGroup)) {
            return ($this.Scope.Split('/')[4])
        }
        return $null
    }
    [string] IsResourceProvider() {

        if ($this.Scope -match $this.regex_managementgroupProvider) {
            return (($this.regex_managementgroupProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[1]
        }
        if ($this.Scope -match $this.regex_subscriptionProvider) {
            return (($this.regex_subscriptionProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[1]
        }
        if ($this.Scope -match $this.regex_resourceGroupProvider) {
            return (($this.regex_resourceGroupProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[1]
        }

        return $null
    }
    [string] IsResource() {

        if ($this.Scope -match $this.regex_managementgroupResource) {
            return ($this.regex_managementgroupResource.Split($this.Scope) | Select-Object -last 1)
        }
        if ($this.Scope -match $this.regex_subscriptionResource) {
            return ($this.regex_subscriptionResource.Split($this.Scope) | Select-Object -last 1)
        }
        if ($this.Scope -match $this.regex_resourceGroupResource) {
            return ($this.regex_resourceGroupResource.Split($this.Scope) | Select-Object -last 1)
        }
        return $null
    }
    #endregion Validators

    #region Data Accessors
    <#
        Should Return Management Group Name
    #>
    [string] GetManagementGroup() {

        if ($this.GetManagementGroupName()) {
            foreach ($mgmt in $script:AzOpsAzManagementGroup) {
                if ($mgmt.DisplayName -eq $this.GetManagementGroupName()) {
                    return $mgmt.Name
                }
            }
        }
        if ($this.Subscription) {
            foreach ($mgmt in $script:AzOpsAzManagementGroup) {
                foreach ($child in $mgmt.Children) {
                    if ($child.DisplayName -eq $this.subscriptionDisplayName) {
                        return $mgmt.Name
                    }
                }
            }
        }
        return $null
    }

    [string] GetAzOpsManagementGroupPath([string]$managementgroupName) {
        if ($groupObject = $script:AzOpsAzManagementGroup | Where-Object Name -eq $managementgroupName) {
            $parentMgName = $groupObject.parentId -split "/" | Select-Object -Last 1
            $parentObject = $script:AzOpsAzManagementGroup | Where-Object Name -eq $parentMgName
            if ($groupObject.parentId -and $parentObject) {
                $parentPath = $this.GetAzOpsManagementGroupPath($parentMgName)
                $childpath = "{0} ({1})" -f $groupObject.DisplayName, $parentObject.Name
                return (join-path $parentPath -ChildPath $childPath)
            }
            else {
                $childPath = "{0} ({1})" -f $groupObject.DisplayName, $groupObject.Name
                return (join-path $this.StateRoot -ChildPath $childPath)
            }
        }
        else {
            Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.GetAzOpsManagementGroupPath.NotFound' -StringValues $managementgroupName -FunctionName AzOpsScope -ModuleName AzOps
            throw "Management Group not found: $managementgroupName"
        }
    }

    <#
        Should Return Management Group Display Name
    #>
    [string] GetManagementGroupName() {
        if ($this.Scope -match $this.regex_managementgroupExtract) {
            $mgId = $this.Scope -split $this.regex_managementgroupExtract -split '/' | Where-Object { $_ } | Select-Object -First 1

            if ($mgId) {
                $mgDisplayName = ($script:AzOpsAzManagementGroup | Where-Object Name -eq $mgId).DisplayName
                if ($mgDisplayName) {
                    Write-PSFMessage -Level Debug -String 'AzOpsScope.GetManagementGroupName.Found.Azure' -StringValues $mgDisplayName -FunctionName AzOpsScope -ModuleName AzOps
                    return $mgDisplayName
                }
                else {
                    Write-PSFMessage -Level Debug -String 'AzOpsScope.GetManagementGroupName.NotFound' -StringValues $mgId -FunctionName AzOpsScope -ModuleName AzOps
                    return $mgId
                }
            }
        }
        if ($this.Subscription) {
            foreach ($managementGroup in $script:AzOpsAzManagementGroup) {
                foreach ($child in $managementGroup.Children) {
                    if ($child.DisplayName -eq $this.subscriptionDisplayName) {
                        return $managementGroup.DisplayName
                    }
                }
            }
        }
        return $null
    }
    [string] GetAzOpsSubscriptionPath() {
        $childpath = "{0} ({1})" -f $this.SubscriptionDisplayName, $this.Subscription
        return join-path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath $childpath
    }
    [string] GetAzOpsResourceGroupPath() {

        return join-path $this.GetAzOpsSubscriptionPath() -ChildPath $this.ResourceGroup
    }
    [string] GetSubscription() {
        if ($this.Scope -match $this.regex_subscriptionExtract) {

            $subId = $this.Scope -split $this.regex_subscriptionExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
            $sub = $script:AzOpsSubscriptions | Where-Object subscriptionId -eq $subId
            if ($sub) {
                Write-PSFMessage -Level Debug -String 'AzOpsScope.GetSubscription.Found' -StringValues $sub.Id -FunctionName AzOpsScope -ModuleName AzOps
                return $sub.subscriptionId
            }
            else {
                Write-PSFMessage -Level Debug -String 'AzOpsScope.GetSubscription.NotFound' -StringValues $subId -FunctionName AzOpsScope -ModuleName AzOps
                return $subId
            }
        }
        return $null
    }
    [string] GetSubscriptionDisplayName() {
        if ($this.Scope -match $this.regex_subscriptionExtract) {

            $subId = $this.Scope -split $this.regex_subscriptionExtract -split '/' | Where-Object { $_ } | Select-Object -First 1
            $sub = $script:AzOpsSubscriptions | Where-Object subscriptionId -eq $subId
            if ($sub) {
                Write-PSFMessage -Level Debug -String 'AzOpsScope.GetSubscriptionDisplayName.Found' -StringValues $sub.displayName -FunctionName AzOpsScope -ModuleName AzOps
                return $sub.displayName
            }
            else {
                Write-PSFMessage -Level Debug -String 'AzOpsScope.GetSubscriptionDisplayName.NotFound' -StringValues $subId -FunctionName AzOpsScope -ModuleName AzOps
                return $subId
            }
        }
        return $null
    }
    [string] GetResourceGroup() {

        if ($this.Scope -match $this.regex_resourceGroupExtract) {
            return ($this.Scope -split $this.regex_resourceGroupExtract -split '/' | Where-Object { $_ } | Select-Object -First 1)
        }
        return $null
    }
    [string] GetResource() {

        if ($this.Scope -match $this.regex_managementgroupProvider) {
            return (($this.regex_managementgroupProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[2]
        }
        if ($this.Scope -match $this.regex_subscriptionProvider) {
            return (($this.regex_subscriptionProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[2]
        }
        if ($this.Scope -match $this.regex_resourceGroupProvider) {
            return (($this.regex_resourceGroupProvider.Split($this.Scope) | Select-Object -last 1) -split '/')[2]
        }

        return $null
    }

    [string] GetAzOpsResourcePath() {

        Write-PSFMessage -Level Debug -String 'AzOpsScope.GetAzOpsResourcePath.Retrieving' -StringValues $this.Scope -FunctionName AzOpsScope -ModuleName AzOps
        if ($this.Scope -match $this.regex_resourceGroupResource) {
            $rgpath = $this.GetAzOpsResourceGroupPath()
            return (Join-Path (Join-Path $rgpath -ChildPath ".AzState") -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name))
        }
        elseif ($this.Scope -match $this.regex_subscriptionResource) {
            $subpath = $this.GetAzOpsSubscriptionPath()
            return (Join-Path (Join-path $subpath -ChildPath ".AzState") -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name))
        }
        elseif ($this.Scope -match $this.regex_managementgroupResource) {
            $mgmtPath = $this.GetAzOpsManagementGroupPath($this.ManagementGroup)
            return (Join-Path (Join-path $mgmtPath -ChildPath ".AzState") -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name))
        }
        Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.GetAzOpsResourcePath.NotFound' -StringValues $this.Scope -FunctionName AzOpsScope -ModuleName AzOps
        throw "Unable to determine Resource Scope for: $($this.Scope)"
    }
    #endregion Data Accessors
}