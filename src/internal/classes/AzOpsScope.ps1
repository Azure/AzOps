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
    [string]$ChildResourceName

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
    hidden [regex]$regex_subscriptionResource = '(?i)^/subscriptions/([0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})/providers/[\s\S]*/[\s\S]*/'
    hidden [regex]$regex_resourceGroupResource = '(?i)^/subscriptions/([0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})/resourcegroups/[\s\S]*/providers/[\s\S]*/[\s\S]*/'
    #endregion Internal Regex Helpers

    #region Constructors
    AzOpsScope ([string]$Scope, [string]$StateRoot) {

        <#
            .SYNOPSIS
                Creates an AzOpsScope based on the specified resource ID or File System Path
            .DESCRIPTION
                Creates an AzOpsScope based on the specified resource ID or File System Path
            .PARAMETER Scope
                Scope == ResourceID or File System Path
            .INPUTS
                None. You cannot pipe objects to Add-Extension.
            .OUTPUTS
                System.String. Add-Extension returns a string with the extension or file name.
            .EXAMPLE
                New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"
                Creates an AzOpsScope based on the specified resource ID
        #>

        Write-PSFMessage -Level Verbose -String 'AzOpsScope.Constructor' -StringValues $scope -FunctionName AzOpsScope -ModuleName AzOps
        $this.StateRoot = $StateRoot
        if (Test-Path -Path $scope) {
            if ((Get-Item $scope -Force).GetType().ToString() -eq 'System.IO.FileInfo') {
                #Strong confidence based on content - file
                Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile' -StringValues $scope -FunctionName AzOpsScope -ModuleName AzOps
                $this.InitializeMemberVariablesFromFile($Scope)
            }
            else {
                # Weak confidence based on metadata at scope - directory
                Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromDirectory' -StringValues $scope -FunctionName AzOpsScope -ModuleName AzOps
                $this.InitializeMemberVariablesFromDirectory($Scope)
            }
        }
        else {
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariables' -StringValues $scope -FunctionName AzOpsScope -ModuleName AzOps
            $this.InitializeMemberVariables($Scope)
        }
    }
    # Overridden Constructor used for Extended Child Resource Discovery
    AzOpsScope ([string]$Scope, [hashtable]$ExtendedChildResource, [string]$StateRoot) {
        <#
            .SYNOPSIS
                Creates an StatePath of Child Resource based on the specified resource ID of ResourceGroup, Resource provider of Resource and Resource name
            .DESCRIPTION
                Creates an StatePath of Child Resource based on the specified resource ID of ResourceGroup, Resource provider of Resource and Resource name
            .PARAMETER Scope
                Scope == ResourceID of Parent resource
            .PARAMETER ExtendedChildResource
                The ExtendedChildResource contains details of the child resource
            .INPUTS
                None. You cannot pipe objects to Add-Extension.
            .OUTPUTS
                Creates an StatePath of Child Resource
            .EXAMPLE
                New-AzOpsScope -Scope "/subscriptions/7d57452c-d765-4fc6-87ec-6649c37f0a0a/resourceGroups/resourcegroup" -ResourceProvider "Microsoft.Network/virtualHubs/hubRouteTables" -ResourceName "hubroutetable1"
                Using Parent Resource id , Resource provider and Resource name it generates a statepath to place the Child Resource file and parent scope Object
        #>
        $this.StateRoot = $StateRoot
        $this.ChildResourceName = $ExtendedChildResource.resourceProvider + '-' + $ExtendedChildResource.resourceName
        Write-PSFMessage -Level Verbose -String 'AzOpsScope.ChildResource.InitializeMemberVariables' -StringValues $ExtendedChildResource.ResourceProvider, $ExtendedChildResource.ResourceName, $scope -FunctionName AzOpsScope -ModuleName AzOps
        $this.InitializeMemberVariables($Scope)
    }

    # Overloaded constructors -  repeat member assignments in each constructor definition
    #AzOpsScope ([System.IO.DirectoryInfo]$Path, [string]$StateRoot) {
    hidden [void] InitializeMemberVariablesFromDirectory([System.IO.DirectoryInfo]$Path) {

        $managementGroupFileName = "microsoft.management_managementGroups-*$(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')"
        $subscriptionFileName = "microsoft.subscription_subscriptions-*$(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')"
        $resourceGroupFileName = "microsoft.resources_resourceGroups-*$(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')"

        if ($Path.FullName -eq (Get-Item $this.StateRoot -Force).FullName) {
            # Root tenant path
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromDirectory.RootTenant' -StringValues $Path -FunctionName InitializeMemberVariablesFromDirectory -ModuleName AzOps
            $this.InitializeMemberVariables("/")
            return
        }
        # Always look into AutoGeneratedTemplateFolderPath folder regardless of path specified
        if ($Path.FullName -notlike "*$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')") {
            $Path = Join-Path $Path -ChildPath "$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')".ToLower()
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromDirectory.AutoGeneratedFolderPath' -StringValues $Path -FunctionName InitializeMemberVariablesFromDirectory -ModuleName AzOps
        }

        if ($managementGroupScopeFile = (Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $managementGroupFileName)) {
            [string] $managementGroupID = $managementGroupScopeFile.Name.Replace('microsoft.management_managementgroups-', '').Replace('.parameters', '').Replace($(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'), '')
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.Input.FromFileName.ManagementGroup' -StringValues $managementGroupID -FunctionName InitializeMemberVariablesFromDirectory -ModuleName AzOps
            $this.InitializeMemberVariables("/providers/Microsoft.Management/managementGroups/$managementGroupID")
        }
        elseif ($subscriptionScopeFileName = (Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $subscriptionFileName)) {
            [string] $subscriptionID = $subscriptionScopeFileName.Name.Replace('microsoft.subscription_subscriptions-', '').Replace('.parameters', '').Replace($(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'), '')
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.Input.FromFileName.Subscription' -StringValues $subscriptionID -FunctionName InitializeMemberVariablesFromDirectory -ModuleName AzOps
            $this.InitializeMemberVariables("/subscriptions/$subscriptionID")
        }
        elseif ((Get-ChildItem -Force -Path $Path -File | Where-Object Name -like $resourceGroupFileName) -or
            ((Get-ChildItem -Force -Path $Path.Parent -File | Where-Object Name -like $subscriptionFileName))
        ) {
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromDirectory.ParentSubscription' -StringValues $Path.Parent -FunctionName InitializeMemberVariablesFromDirectory -ModuleName AzOps

            if ($(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath') -match $Path.Name) {
                $parent = New-AzOpsScope -Path ($Path.Parent.Parent)
                $rgName = $Path.Parent.Name
            }
            else {
                $parent = New-AzOpsScope -Path ($Path.Parent)
                $rgName = $Path.Name
            }

            $this.InitializeMemberVariables($("/subscriptions/{0}/resourceGroups/{1}" -f $parent.Subscription, $rgName))
        }
        else {
            #Error
            Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.Input.BadData.UnknownType' -StringValues $Path -FunctionName AzOpsScope -ModuleName AzOps
            throw "Invalid File Structure! Cannot find Management Group / Subscription / Resource Group files in $Path!"
        }
    }

    #AzOpsScope ([System.IO.FileInfo]$Path, [string]$StateRoot) {
    hidden [void] InitializeMemberVariablesFromFile([System.IO.FileInfo]$Path) {
        if (-not $Path.Exists) { throw 'Invalid Input!' }

        if ($Path.Extension -ne '.json') {
            # Try to determine based on directory
            Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.NotJson' -StringValues $Path -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
            $this.InitializeMemberVariablesFromDirectory($Path.Directory)
            return
        }
        else {
            $resourcePath = Get-Content $Path | ConvertFrom-Json -AsHashtable

            if (!$resourcePath) {
                # Empty file with .json is not valid JSON file. Empty Json should've minimum file content '{}'
                # However, due to bug that is combination of Get-Content and ConvertFrom-Json when empty file with .json (that is valid file but not valid Json),
                # switch statement is failing to handle $null value unless assigned explicitly.
                $resourcePath = $null
            }

            switch ($resourcePath) {
                { $_.parameters.input.value.Keys -contains "ResourceId" } {
                    # Parameter Files - resource from parameters file
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.ResourceId' -StringValues $($resourcePath.parameters.input.value.ResourceId) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $this.InitializeMemberVariables($resourcePath.parameters.input.value.ResourceId)
                    break
                }
                { $_.parameters.input.value.Keys -contains "Id" } {
                    # Parameter Files - ManagementGroup and Subscription
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.Id' -StringValues $($resourcePath.parameters.input.value.Id) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $this.InitializeMemberVariables($resourcePath.parameters.input.value.Id)
                    break
                }
                { $_.parameters.input.value.Keys -contains "Type" } {
                    # Parameter Files - Determine Resource Type and Name (Management group)
                    # Management group resource id do contain '/provider'
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.Type' -StringValues ("$($resourcePath.parameters.input.value.Type)/$($resourcePath.parameters.input.value.Name)") -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $this.InitializeMemberVariables("$($resourcePath.parameters.input.value.Type)/$($resourcePath.parameters.input.value.Name)")
                    break
                }
                { $_.parameters.input.value.Keys -contains "ResourceType" } {
                    # Parameter Files - Determine Resource Type and Name (Any ResourceType except management group)
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.ResourceType' -StringValues ($resourcePath.parameters.input.value.ResourceType) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $currentScope = New-AzOpsScope -Path ($Path.Directory)

                    # Creating Resource Id based on current scope, resource Type and Name of the resource
                    $this.InitializeMemberVariables("$($currentScope.scope)/providers/$($resourcePath.parameters.input.value.ResourceType)/$($resourcePath.parameters.input.value.Name)")
                    break
                }
                { $_.resources -and
                    $_.resources[0].type -eq 'Microsoft.Management/managementGroups' } {
                    # Template - Management Group
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.managementgroups' -StringValues ($_.resources[0].name) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $currentScope = New-AzOpsScope -Path ($Path.Directory)
                    $this.InitializeMemberVariables("$($currentScope.scope)")
                    break
                }
                { $_.resources -and
                    $_.resources[0].type -eq 'Microsoft.Management/managementGroups/subscriptions' } {
                    # Template - Subscription
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.subscriptions' -StringValues ($_.resources[0].name) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps
                    $currentScope = New-AzOpsScope -Path ($Path.Directory.Parent)
                    $this.InitializeMemberVariables("$($currentScope.scope)")
                    break
                }
                { $_.resources -and
                    $_.resources[0].type -eq 'Microsoft.Resources/resourceGroups' } {
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.resourceGroups' -StringValues ($_.resources[0].name) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps

                    if ($(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath') -match $Path.Directory.Name) {
                        $currentScope = New-AzOpsScope -Path ($Path.Directory.Parent)
                    }
                    else {
                        $currentScope = New-AzOpsScope -Path ($Path.Directory)
                    }

                    $this.InitializeMemberVariables("$($currentScope.scope)")
                    break
                }
                { $_.resources } {
                    # Template - 1st resource
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromFile.resource' -StringValues ($_.resources[0].type), ($_.resources[0].name) -FunctionName InitializeMemberVariablesFromFile -ModuleName AzOps

                    if ($(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath') -match $Path.Directory.Name) {
                        $currentScope = New-AzOpsScope -Path ($Path.Directory.Parent)
                    }
                    else {
                        $currentScope = New-AzOpsScope -Path ($Path.Directory)
                    }

                    $this.InitializeMemberVariables("$($currentScope.scope)/providers/$($_.resources[0].type)/$($_.resources[0].name)")
                    break
                }
                Default {
                    Write-PSFMessage -Level Warning  -String 'AzOpsScope.Input.BadData.TemplateParameterFile' -StringValues $Path -FunctionName AzOpsScope -ModuleName AzOps
                    Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariablesFromDirectory' -StringValues $Path -FunctionName AzOpsScope -ModuleName AzOps
                    $this.InitializeMemberVariablesFromDirectory($Path.Directory)
                }
            }
        }
    }
    #endregion Constructors

    hidden [void] InitializeMemberVariables([string]$Scope) {
        Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariables.Start' -StringValues ($scope) -FunctionName InitializeMemberVariables -ModuleName AzOps
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
                if ( (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix') -notcontains 'parameters.json' -and
                    ("$($this.ResourceProvider)/$($this.Resource)" -in 'Microsoft.Authorization/policyDefinitions', 'Microsoft.Authorization/policySetDefinitions')
                ) {
                    $this.StatePath = ($this.GetAzOpsResourcePath() + '.parameters' + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
                }
                else {
                    $this.StatePath = ($this.GetAzOpsResourcePath() + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
                }
            }
        }
        elseif ($this.IsResourceGroup()) {
            $this.Type = "resourcegroups"
            $this.ResourceProvider = "Microsoft.Resources"
            $this.Resource = "resourceGroups"
            $this.Name = $this.IsResourceGroup()
            $this.Subscription = $this.GetSubscription()
            $this.SubscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.ManagementGroup = $this.GetManagementGroup()
            $this.ManagementGroupDisplayName = $this.GetManagementGroupName()
            $this.ResourceGroup = $this.GetResourceGroup()
            if ($this.ChildResourceName -and (-not(Get-PSFConfigValue -FullName AzOps.Core.SkipExtendedChildResourcesDiscovery ))) {
                $this.StatePath = (Join-Path $this.GetAzOpsResourceGroupPath() -ChildPath ("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\$($this.ChildResourceName).json").ToLower())
            }
            elseif (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (Join-Path $this.GetAzOpsResourceGroupPath() -ChildPath ("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.resources_resourcegroups-$($this.ResourceGroup).json").ToLower() )
            }
            else {
                $this.StatePath = (Join-Path $this.GetAzOpsResourceGroupPath() -ChildPath ("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.resources_resourcegroups-$($this.ResourceGroup)" + $(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')).ToLower())
            }
        }
        elseif ($this.IsSubscription()) {
            $this.Type = "subscriptions"
            $this.ResourceProvider = "Microsoft.Management"
            $this.Resource = "managementGroups/subscriptions"
            $this.Name = $this.IsSubscription()
            $this.Subscription = $this.GetSubscription()
            $this.SubscriptionDisplayName = $this.GetSubscriptionDisplayName()
            if ($script:AzOpsAzManagementGroup) {
                $this.ManagementGroup = $this.GetManagementGroup()
                $this.ManagementGroupDisplayName = $this.GetManagementGroupName()
            }
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (Join-Path $this.GetAzOpsSubscriptionPath() -ChildPath ("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.subscription_subscriptions-$($this.Subscription).json").ToLower())
            }
            else {
                $this.StatePath = (Join-Path $this.GetAzOpsSubscriptionPath() -ChildPath (("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.subscription_subscriptions-$($this.Subscription)" + $(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))).ToLower())
            }

        }
        elseif ($this.IsManagementGroup()) {
            $this.Type = "managementGroups"
            $this.ResourceProvider = "Microsoft.Management"
            $this.Resource = "managementGroups"
            $this.Name = $this.GetManagementGroup()
            $this.ManagementGroup = ($this.GetManagementGroup()).Trim()
            $this.ManagementGroupDisplayName = ($this.GetManagementGroupName()).Trim()
            if (Get-PSFConfigValue -FullName AzOps.Core.ExportRawTemplate) {
                $this.StatePath = (Join-Path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath ("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.management_managementgroups-$($this.ManagementGroup).json").ToLower())
            }
            else {
                $this.StatePath = (Join-Path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath (("$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')\microsoft.management_managementgroups-$($this.ManagementGroup)" + $(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))).ToLower())
            }
        }
        elseif ($this.IsRoot()) {
            $this.Type = "root"
            $this.Name = "/"
            $this.StatePath = $this.StateRoot.ToLower()
        }
        Write-PSFMessage -Level Verbose -String 'AzOpsScope.InitializeMemberVariables.End' -StringValues ($scope) -FunctionName InitializeMemberVariables -ModuleName AzOps
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
                $childPath = "{0} ({1})" -f $groupObject.DisplayName, $groupObject.Name
                return Join-Path $parentPath -ChildPath ($childPath.ToLower())
            }
            else {
                $childPath = "{0} ({1})" -f $groupObject.DisplayName, $groupObject.Name
                return Join-Path $this.StateRoot -ChildPath ($childPath.ToLower())
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
                    #Write-PSFMessage -Level Debug -String 'AzOpsScope.GetManagementGroupName.Found.Azure' -StringValues $mgDisplayName -FunctionName AzOpsScope -ModuleName AzOps
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
        if ($script:AzOpsAzManagementGroup) {
            return (Join-Path $this.GetAzOpsManagementGroupPath($this.ManagementGroup) -ChildPath ($childpath).ToLower())
        }
        else {
            return (Join-Path $this.StateRoot -ChildPath ($childpath).ToLower())
        }
    }
    [string] GetAzOpsResourceGroupPath() {
        return (Join-Path $this.GetAzOpsSubscriptionPath() -ChildPath ($this.ResourceGroup).ToLower())
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
            return (Join-Path (Join-Path $rgpath -ChildPath "$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')".ToLower()) -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name).ToLower())
        }
        elseif ($this.Scope -match $this.regex_subscriptionResource) {
            $subpath = $this.GetAzOpsSubscriptionPath()
            return (Join-Path (Join-Path $subpath -ChildPath "$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')".ToLower()) -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name).ToLower())
        }
        elseif ($this.Scope -match $this.regex_managementgroupResource) {
            $mgmtPath = $this.GetAzOpsManagementGroupPath($this.ManagementGroup)
            return (Join-Path (Join-Path $mgmtPath -ChildPath "$(Get-PSFConfigValue -FullName 'AzOps.Core.AutoGeneratedTemplateFolderPath')".ToLower()) -ChildPath ($this.ResourceProvider + "_" + $this.Resource + "-" + $this.Name).ToLower())
        }
        Write-PSFMessage -Level Warning -Tag error -String 'AzOpsScope.GetAzOpsResourcePath.NotFound' -StringValues $this.Scope -FunctionName AzOpsScope -ModuleName AzOps
        throw "Unable to determine Resource Scope for: $($this.Scope)"
    }
    #endregion Data Accessors
}
