﻿function Get-AzOpsResourceDefinition {

    <#
        .SYNOPSIS
            This cmdlet recursively discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Privileged Identity Management resources, Policies, Role Assignments) from the provided input scope.
        .DESCRIPTION
            This cmdlet recursively discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Privileged Identity Management resources, Policies, Role Assignments) from the provided input scope.
        .PARAMETER Scope
            Discovery Scope
        .PARAMETER IncludeResourcesInResourceGroup
            Discover only resources in these resource groups.
        .PARAMETER IncludeResourceType
            Discover only specific resource types.
        .PARAMETER SkipChildResource
            Skip childResource discovery.
        .PARAMETER SkipPim
            Skip discovery of Privileged Identity Management resources.
        .PARAMETER SkipPolicy
            Skip discovery of policies for better performance.
        .PARAMETER SkipResource
            Skip discovery of resources inside resource groups.
        .PARAMETER SkipResourceGroup
            Skip discovery of resource groups.
        .PARAMETER SkipResourceType
            Skip discovery of specific resource types.
        .PARAMETER SkipRole
            Skip discovery of roles for better performance.
        .PARAMETER ExportRawTemplate
            Export generic templates without embedding them in the parameter block.
        .PARAMETER StatePath
            The root folder under which to write the resource json.
        .EXAMPLE
            $TenantRootId = '/providers/Microsoft.Management/managementGroups/{0}' -f (Get-AzTenant).Id
            Get-AzOpsResourceDefinition -scope $TenantRootId -Verbose
            Discover all resources from root Management Group
        .EXAMPLE
            Get-AzOpsResourceDefinition -scope /providers/Microsoft.Management/managementGroups/landingzones -SkipPolicy -SkipResourceGroup
            Discover all resources from child Management Group, skip discovery of policies and resource groups
        .EXAMPLE
            Get-AzOpsResourceDefinition -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c
            Discover all resources from Subscription level
        .EXAMPLE
            Get-AzOpsResourceDefinition -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c/resourceGroups/myresourcegroup
            Discover all resources from resource group level
        .EXAMPLE
            Get-AzOpsResourceDefinition -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c/resourceGroups/contoso-global-dns/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net
            Discover a single resource
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Scope,

        [string[]]
        $IncludeResourcesInResourceGroup = (Get-PSFConfigValue -FullName 'AzOps.Core.IncludeResourcesInResourceGroup'),

        [string[]]
        $IncludeResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.IncludeResourceType'),

        [switch]
        $SkipChildResource = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipChildResource'),

        [switch]
        $SkipPim = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipPim'),

        [switch]
        $SkipPolicy = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipPolicy'),

        [switch]
        $SkipResource = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipResource'),

        [switch]
        $SkipResourceGroup = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipResourceGroup'),

        [string[]]
        $SkipResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipResourceType'),

        [switch]
        $SkipRole = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipRole'),

        [switch]
        $ExportRawTemplate = (Get-PSFConfigValue -FullName 'AzOps.Core.ExportRawTemplate'),

        [Parameter(Mandatory = $false)]
        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    begin {
        #region Utility Functions
        function ConvertFrom-TypeResource {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                [AzOpsScope]
                $ScopeObject,

                [string]
                $StatePath,

                [switch]
                $ExportRawTemplate
            )

            process {
                $common = @{
                    FunctionName = 'Get-AzOpsResourceDefinition'
                    Target       = $ScopeObject
                }

                Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Resource.Processing' -StringValues $ScopeObject.Resource, $ScopeObject.ResourceGroup
                try {
                    $resource = Get-AzResource -ResourceId $ScopeObject.scope -ErrorAction Stop
                    ConvertTo-AzOpsState -Resource $resource -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate
                }
                catch {
                    Write-PSFMessage -Level Warning @common -String 'Get-AzOpsResourceDefinition.Resource.Processing.Failed' -StringValues $ScopeObject.Resource, $ScopeObject.ResourceGroup -ErrorRecord $_
                }
            }
        }

        function ConvertFrom-TypeResourceGroup {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                [AzOpsScope]
                $ScopeObject,

                [string[]]
                $IncludeResourcesInResourceGroup,

                [string[]]
                $IncludeResourceType,

                [switch]
                $SkipResource,

                [string[]]
                $SkipResourceType,

                [string]
                $StatePath,

                [switch]
                $ExportRawTemplate,

                $Context,

                [string]
                $OdataFilter
            )

            process {
                $common = @{
                    FunctionName = 'Get-AzOpsResourceDefinition'
                    Target       = $ScopeObject
                }

                Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing' -StringValues $ScopeObject.Resourcegroup, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription

                try {
                    if ($IncludeResourcesInResourceGroup -eq "*") {
                        Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing' -StringValues $resourceGroup.ResourceGroupName, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
                        $resourceGroup = Get-AzResourceGroup -Name $ScopeObject.ResourceGroup -DefaultProfile $Context -ErrorAction Stop
                    }
                    else {
                        if ($ScopeObject.ResourceGroup -in $IncludeResourcesInResourceGroup) {
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing' -StringValues $resourceGroup.ResourceGroupName, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
                            $resourceGroup = Get-AzResourceGroup -Name $ScopeObject.ResourceGroup -DefaultProfile $Context -ErrorAction Stop
                        }
                    }
                }
                catch {
                    Write-PSFMessage -Level Warning @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing.Error' -StringValues $ScopeObject.Resourcegroup, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -ErrorRecord $_
                    return
                }
                if ($resourceGroup.ManagedBy) {
                    Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing.Owned' -StringValues $resourceGroup.ResourceGroupName, $resourceGroup.ManagedBy
                    return
                }
                ConvertTo-AzOpsState -Resource $resourceGroup -ExportRawTemplate:$ExportRawTemplate -StatePath $StatePath

                # Get all resources in resource groups
                $paramGetAzResource = @{
                    DefaultProfile    = $Context
                    ResourceGroupName = $resourceGroup.ResourceGroupName
                    ODataQuery        = $OdataFilter
                    ExpandProperties  = $true
                }
                if ($IncludeResourceType -eq "*") {
                    Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing.Resources' -StringValues $resourceGroup.ResourceGroupName, $ScopeObject.SubscriptionDisplayName
                    Get-AzResource @paramGetAzResource | Where-Object { $_.Type -notin $SkipResourceType } | ForEach-Object {
                        New-AzOpsScope -Scope $_.ResourceId
                    } | ConvertFrom-TypeResource -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate
                }
                else {
                    foreach ($ResourceType in $IncludeResourceType) {
                        Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.ResourceGroup.Processing.Resources' -StringValues $resourceGroup.ResourceGroupName, $ScopeObject.SubscriptionDisplayName
                        Get-AzResource -ResourceType $ResourceType @paramGetAzResource | Where-Object { $_.Type -notin $SkipResourceType } | ForEach-Object {
                            New-AzOpsScope -Scope $_.ResourceId
                        } | ConvertFrom-TypeResource -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate
                    }
                }
            }
        }

        function ConvertFrom-TypeSubscription {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                [AzOpsScope]
                $ScopeObject,

                [string[]]
                $IncludeResourcesInResourceGroup,

                [string[]]
                $IncludeResourceType,

                [switch]
                $SkipPim,

                [switch]
                $SkipPolicy,

                [switch]
                $SkipResource,

                [switch]
                $SkipResourceGroup,

                [string[]]
                $SkipResourceType,

                [switch]
                $SkipRole,

                [string]
                $StatePath,

                [switch]
                $ExportRawTemplate,

                $Context,

                [string]
                $ODataFilter
            )

            begin {
                # Set variables for retry with exponential backoff
                $backoffMultiplier = 2
                $maxRetryCount = 6
            }

            process {
                $common = @{
                    FunctionName = 'Get-AzOpsResourceDefinition'
                    Target       = $ScopeObject
                }

                Write-PSFMessage -Level Important @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription

                # Skip discovery of resource groups if SkipResourceGroup switch have been used
                # Separate discovery of resource groups in subscriptions to support parallel discovery
                if ($SkipResourceGroup) {
                    Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.SkippingResourceGroup'
                }
                else {
                    # Get all Resource Groups in Subscription
                    # Retry loop with exponential back off implemented to catch errors
                    # Introduced due to error "Your Azure Credentials have not been set up or expired"
                    # https://github.com/Azure/azure-powershell/issues/9448
                    # Define variables used by script


                    if (
                        (((Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') | Foreach-Object { $scopeObject.Subscription -like $_ }) -contains $true) -or
                        (((Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') | Foreach-Object { $scopeObject.SubscriptionDisplayName -like $_ }) -contains $true)
                    ) {
                        $resourceGroups = Invoke-AzOpsScriptBlock -ArgumentList $Context -ScriptBlock {
                            param ($Context)
                            Get-AzResourceGroup -DefaultProfile ($Context | Write-Output) -ErrorAction Stop | Where-Object { -not $_.ManagedBy }
                        } -RetryCount $maxRetryCount -RetryWait $backoffMultiplier -RetryType Exponential
                        if (-not $resourceGroups) {
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.NoResourceGroup' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
                        }

                        #region Prepare Input Data for parallel processing
                        $runspaceData = @{
                            AzOpsPath                       = "$($script:ModuleRoot)\AzOps.psd1"
                            StatePath                       = $StatePath
                            ScopeObject                     = $ScopeObject
                            ODataFilter                     = $ODataFilter
                            SkipPim                         = $SkipPim
                            SkipPolicy                      = $SkipPolicy
                            SkipRole                        = $SkipRole
                            SkipResource                    = $SkipResource
                            SkipChildResource               = $SkipChildResource
                            SkipResourceType                = $SkipResourceType
                            IncludeResourcesInResourceGroup = $IncludeResourcesInResourceGroup
                            IncludeResourceType             = $IncludeResourceType
                            MaxRetryCount                   = $maxRetryCount
                            BackoffMultiplier               = $backoffMultiplier
                            ExportRawTemplate               = $ExportRawTemplate
                            runspace_AzOpsAzManagementGroup = $script:AzOpsAzManagementGroup
                            runspace_AzOpsSubscriptions     = $script:AzOpsSubscriptions
                            runspace_AzOpsPartialRoot       = $script:AzOpsPartialRoot
                            runspace_AzOpsResourceProvider  = $script:AzOpsResourceProvider
                        }
                        #endregion Prepare Input Data for parallel processing

                        #region Discover all resource groups in parallel
                        $resourceGroups | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                            $resourceGroup = $_
                            $runspaceData = $using:runspaceData

                            $msgCommon = @{
                                FunctionName = 'Get-AzOpsResourceDefinition'
                                ModuleName   = 'AzOps'
                            }

                            # region Importing module
                            # We need to import all required modules and declare variables again because of the parallel runspaces
                            # https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/
                            Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                            $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru
                            # endregion Importing module

                            & $azOps {
                                $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                                $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                                $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                                $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                            }

                            $context = Get-AzContext
                            $context.Subscription.Id = $runspaceData.ScopeObject.Subscription

                            Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SubScription.Processing.ResourceGroup' -StringValues $resourceGroup.ResourceGroupName -Target $resourceGroup
                            & $azOps { ConvertTo-AzOpsState -Resource $resourceGroup -ExportRawTemplate:$runspaceData.ExportRawTemplate -StatePath $runspaceData.Statepath }

                            #region Process Privileged Identity Management resources, Policies and Roles at RG scope
                            if ((-not $using:SkipPim) -or (-not $using:SkipPolicy) -or (-not $using:SkipRole)) {
                                & $azOps {
                                    $rgScopeObject = New-AzOpsScope -Scope $resourceGroup.ResourceId -StatePath $runspaceData.Statepath -ErrorAction Stop
                                    if (-not $using:SkipPim) {
                                        Get-AzOpsPim -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                                    }
                                    if (-not $using:SkipPolicy) {
                                        Get-AzOpsPolicy -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                                    }
                                    if (-not $using:SkipRole) {
                                        Get-AzOpsRole -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                                    }
                                }
                            }
                            #endregion Process Privileged Identity Management resources, Policies and Roles at RG scope

                            if (-not $using:SkipResource) {
                                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SubScription.Processing.ResourceGroup.Resources' -StringValues $resourceGroup.ResourceGroupName -Target $resourceGroup
                                if ($runspaceData.IncludeResourcesInResourceGroup -ne "*") {
                                    if ($resourceGroup.ResourceGroupName -notin $runspaceData.IncludeResourcesInResourceGroup) {
                                        Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.Processing.IncludeResourcesInRG' -StringValues $resourceGroup.ResourceGroupName -Target $resourceGroup
                                        continue
                                    }
                                }
                                try {
                                    $resources = & $azOps {
                                        $parameters = @{
                                            DefaultProfile = $Context | Select-Object -First 1
                                            ODataQuery     = $runspaceData.ODataFilter
                                        }
                                        if ($resourceGroup.ResourceGroupName) {
                                            $parameters.ResourceGroupName = $resourceGroup.ResourceGroupName
                                        }
                                        Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                                            param (
                                                $Parameters
                                            )
                                            $param = $Parameters | Write-Output
                                            Get-AzResource @param -ExpandProperties -ErrorAction Stop
                                        } -RetryCount $runspaceData.MaxRetryCount -RetryWait $runspaceData.BackoffMultiplier -RetryType Exponential
                                    }
                                }
                                catch {
                                    Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.Resource.Processing.Warning' -StringValues $resourceGroup.ResourceGroupName, $_
                                }

                                if ($runspaceData.IncludeResourceType -eq "*") {
                                    $resources = $resources | Where-Object { $_.Type -notin $runspaceData.SkipResourceType }
                                }
                                else {
                                    $resources = $resources | Where-Object { $_.Type -notin $runspaceData.SkipResourceType -and $_.Type -in $runspaceData.IncludeResourceType }
                                }
                                if (-not $resources) {
                                    Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SubScription.Processing.ResourceGroup.NoResources' -StringValues $resourceGroup.ResourceGroupName -Target $resourceGroup
                                }
                                $tempExportPath = [System.IO.Path]::GetTempPath() + $resourceGroup.ResourceGroupName + '.json'
                                # Loop through resources and convert them to AzOpsState
                                foreach ($resource in $resources) {
                                    # Convert resources to AzOpsState
                                    Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SubScription.Processing.Resource' -StringValues $resource.Name, $resourceGroup.ResourceGroupName -Target $resource
                                    & $azOps { ConvertTo-AzOpsState -Resource $resource -ExportRawTemplate:$runspaceData.ExportRawTemplate -StatePath $runspaceData.Statepath }
                                    if (-not $using:SkipChildResource) {
                                        try {
                                            $exportParameters = @{
                                                Resource                = $resource.ResourceId
                                                ResourceGroupName       = $resourceGroup.ResourceGroupName
                                                SkipAllParameterization = $true
                                                Path                    = $tempExportPath
                                                DefaultProfile          = $Context | Select-Object -First 1
                                            }
                                            Export-AzResourceGroup @exportParameters -Confirm:$false -Force -ErrorAction Stop | Out-Null
                                            $exportResources = (Get-Content -Path $tempExportPath | ConvertFrom-Json).resources
                                            foreach ($exportResource in $exportResources) {
                                                if (-not(($resource.Name -eq $exportResource.name) -and ($resource.ResourceType -eq $exportResource.type))) {
                                                    Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.Processing.ChildResource' -StringValues $exportResource.Name, $resourceGroup.ResourceGroupName -Target $exportResource
                                                    $ChildResource = @{
                                                        resourceProvider = $exportResource.type -replace '/', '_'
                                                        resourceName     = $exportResource.name -replace '/', '_'
                                                        parentResourceId = $resourceGroup.ResourceId
                                                    }
                                                    if (Get-Member -InputObject $exportResource -name 'dependsOn') {
                                                        $exportResource.PsObject.Members.Remove('dependsOn')
                                                    }
                                                    $resourceHash = @{resources = @($exportResource) }
                                                    & $azOps {
                                                        ConvertTo-AzOpsState -Resource $resourceHash -ChildResource $ChildResource -StatePath $runspaceData.Statepath
                                                    }
                                                }
                                            }
                                        }
                                        catch {
                                            Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.ChildResource.Warning' -StringValues $resourceGroup.ResourceGroupName, $_
                                        }
                                    }
                                    else {
                                        Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.SkippingChildResource' -StringValues $resourceGroup.ResourceGroupName
                                    }
                                }
                                if (Test-Path -Path $tempExportPath) {
                                    Remove-Item -Path $tempExportPath
                                }
                            }
                            else {
                                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.SkippingResources'
                            }
                        }
                        #endregion Discover all resource groups in parallel
                    }
                    else {
                        Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.ExcludeResourceGroup'
                    }
                }

                if ($Script:AzOpsAzManagementGroup.Children) {
                    $subscriptionItem = $script:AzOpsAzManagementGroup.children | Where-Object Name -eq $ScopeObject.name
                }
                else {
                    # Handle subscription-only scenarios without permissions to managementGroups
                    $subscriptionItem = Get-AzSubscription -SubscriptionId $scopeObject.Subscription
                }

                if ($subscriptionItem) {
                    ConvertTo-AzOpsState -Resource $subscriptionItem -ExportRawTemplate:$ExportRawTemplate -StatePath $StatePath
                }
            }
        }

        function ConvertFrom-TypeManagementGroup {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromPipeline = $true)]
                [AzOpsScope]
                $ScopeObject,

                [switch]
                $SkipPim,

                [switch]
                $SkipPolicy,

                [switch]
                $SkipRole,

                [switch]
                $SkipResourceGroup,

                [switch]
                $SkipResource,

                [switch]
                $ExportRawTemplate,

                [string]
                $StatePath
            )
            begin {
                $parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Exclude ScopeObject
            }
            process {
                $common = @{
                    FunctionName = 'Get-AzOpsResourceDefinition'
                    Target       = $ScopeObject
                }

                Write-PSFMessage -Level Important -String 'Get-AzOpsResourceDefinition.ManagementGroup.Processing' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup

                $childOfManagementGroups = ($script:AzOpsAzManagementGroup | Where-Object Name -eq $ScopeObject.ManagementGroup).Children

                foreach ($child in $childOfManagementGroups) {

                    if ($child.Type -eq '/subscriptions') {
                        if ($script:AzOpsSubscriptions.id -contains $child.Id) {
                            Get-AzOpsResourceDefinition -Scope $child.Id @parameters
                        }
                        else {
                            Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.ManagementGroup.Subscription.NotFound' -StringValues $child.Name
                        }
                    }
                    else {
                        Get-AzOpsResourceDefinition -Scope $child.Id @parameters
                    }
                }
                ConvertTo-AzOpsState -Resource ($script:AzOpsAzManagementGroup | Where-Object Name -eq $ScopeObject.ManagementGroup) -ExportRawTemplate:$ExportRawTemplate -StatePath $StatePath
            }
        }
        #endregion Utility Functions
    }

    process {
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing' -StringValues $Scope

        try {
            $scopeObject = New-AzOpsScope -Scope $Scope -StatePath $StatePath -ErrorAction Stop
        }
        catch {
            Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.Processing.NotFound' -StringValues $Scope
            return
        }

        if ($scopeObject.Subscription) {
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Subscription.Found' -StringValues $scopeObject.subscriptionDisplayName, $scopeObject.subscription
            $context = Get-AzContext
            $context.Subscription.Id = $ScopeObject.Subscription
            $odataFilter = "`$filter=subscriptionId eq '$($scopeObject.subscription)'"
            # Exclude resources in SkipResourceType
            $SkipResourceType | Foreach-Object -Process {
                $odataFilter = $odataFilter + " AND resourceType ne '$_'"
            }
            # Include resources from if changed from '*'
            $IncludeResourceType | Where-Object { $_ -ne '*' } | Foreach-Object -Process {
                $odataFilter = $odataFilter + " AND resourceType eq '$_'"
            }
            Write-PSFMessage -Level Debug -String 'Get-AzOpsResourceDefinition.Subscription.OdataFilter' -StringValues $odataFilter
        }

        switch ($scopeObject.Type) {
            resource { ConvertFrom-TypeResource -ScopeObject $scopeObject -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate }
            resourcegroups { ConvertFrom-TypeResourceGroup -ScopeObject $scopeObject -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate -Context $context -SkipResource:$SkipResource -SkipResourceType:$SkipResourceType -OdataFilter $odataFilter -IncludeResourceType $IncludeResourceType -IncludeResourcesInResourceGroup $IncludeResourcesInResourceGroup }
            subscriptions { ConvertFrom-TypeSubscription -ScopeObject $scopeObject -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate -Context $context -SkipResourceGroup:$SkipResourceGroup -SkipResource:$SkipResource -SkipResourceType:$SkipResourceType -SkipPim:$SkipPim -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -ODataFilter $odataFilter -IncludeResourceType $IncludeResourceType -IncludeResourcesInResourceGroup $IncludeResourcesInResourceGroup }
            managementGroups { ConvertFrom-TypeManagementGroup -ScopeObject $scopeObject -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate -SkipPim:$SkipPim -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -SkipResourceGroup:$SkipResourceGroup -SkipResource:$SkipResource }
        }

        if ($scopeObject.Type -notin 'resourcegroups', 'subscriptions', 'managementGroups') {
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Finished' -StringValues $scopeObject.Scope
            return
        }

        #region Process Privileged Identity Management resources
        if (-not $SkipPim) {
            Get-AzOpsPim -ScopeObject $scopeObject -StatePath $StatePath
        }
        #endregion Process Privileged Identity Management resources

        #region Process Policies
        if (-not $SkipPolicy) {
            Get-AzOpsPolicy -ScopeObject $scopeObject -StatePath $StatePath
        }
        #endregion Process Policies

        #region Process Roles
        if (-not $SkipRole) {
            Get-AzOpsRole -ScopeObject $scopeObject -StatePath $StatePath
        }
        #endregion Process Roles

        if ($scopeObject.Type -notin 'subscriptions', 'managementGroups') {
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Finished' -StringValues $scopeObject.Scope
            return
        }
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Finished' -StringValues $scopeObject.Scope
    }
}