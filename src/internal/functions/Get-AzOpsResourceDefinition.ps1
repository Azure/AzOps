function Get-AzOpsResourceDefinition {

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
            Skip discovery of Privileged Identity Management.
        .PARAMETER SkipLock
            Skip discovery of resourceLock.
        .PARAMETER SkipPolicy
            Skip discovery of policies.
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
        $SkipLock = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipLock'),

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
                $SkipLock,

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
                    if (
                        (((Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') | Foreach-Object { $scopeObject.Subscription -like $_ }) -contains $true) -or
                        (((Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') | Foreach-Object { $scopeObject.SubscriptionDisplayName -like $_ }) -contains $true)
                    ) {
                        #region Discover all resource groups at scope
                        $resourceGroupsQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups' | where managedBy == '' | order by ['resourceGroup'] asc"
                        $resourceGroups = Search-AzOpsAzGraph -Context $Context -Query $resourceGroupsQuery -ErrorAction Stop
                        if ($IncludeResourcesInResourceGroup -ne "*") {
                            $resourceGroups = $resourceGroups | Where-Object { $_.name -notin $IncludeResourcesInResourceGroup }
                        }
                        if (-not $resourceGroups) {
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.NoResourceGroup' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
                        }
                        # Loop through resource groups
                        foreach ($resourceGroup in $resourceGroups) {
                            # Convert resourceGroup to AzOpsState
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing.ResourceGroup' -StringValues $resourceGroup.name -Target $resourceGroup
                            ConvertTo-AzOpsState -Resource $resourceGroup -ExportRawTemplate:$ExportRawTemplate -StatePath $Statepath
                        }
                        #endregion Discover all resource groups at scope

                        #region Discover all direct resources at scope (excluding child resources)
                        if (-not $SkipResource) {
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing.Resource.Discovery' -StringValues $ScopeObject.SubscriptionDisplayName
                            try {
                                $resourcesQuery = "resources | order by ['resourceGroup'] asc"
                                $resources = Search-AzOpsAzGraph -Context $Context -Query $resourcesQuery -ErrorAction Stop
                                if ($IncludeResourcesInResourceGroup -ne "*") {
                                    # Filter away resources not matching previous resource group results
                                    $resources = $resources | Where-Object {$_.resourceGroup -in $resourceGroups.name}
                                }
                            }
                            catch {
                                Write-PSFMessage -Level Warning @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing.Resource.Warning' -StringValues $ScopeObject.SubscriptionDisplayName
                            }
                            if ($IncludeResourceType -eq "*") {
                                $resources = $resources | Where-Object { $_.type -notin $SkipResourceType }
                            }
                            else {
                                $resources = $resources | Where-Object { $_.type -notin $SkipResourceType -and $_.type -in $IncludeResourceType }
                            }
                            if (-not $resources) {
                                Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing.Resource.Discovery.NotF' -StringValues $ScopeObject.SubscriptionDisplayName
                            }
                            # Loop through resources
                            foreach ($resource in $resources) {
                                # Convert resources to AzOpsState
                                Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.Processing.Resource' -StringValues $resource.name, $resource.resourcegroup -Target $resource
                                ConvertTo-AzOpsState -Resource $resource -ExportRawTemplate:$ExportRawTemplate -StatePath $Statepath
                            }
                        }
                        else {
                            Write-PSFMessage -Level Verbose @common -String 'Get-AzOpsResourceDefinition.Subscription.SkippingResources'
                        }
                        #endregion Discover all direct resources at scope (excluding child resources)

                        # Remove unsupported resource types from further processing if ChildResource discovery is enabled
                        if (-not $using:SkipChildResource) {
                            $resources = $resources | Where-Object { $_.type -ne 'microsoft.network/connections'}
                        }

                        #region Prepare Input Data for parallel processing
                        $runspaceData = @{
                            AzOpsPath                       = "$($script:ModuleRoot)\AzOps.psd1"
                            StatePath                       = $StatePath
                            ScopeObject                     = $ScopeObject
                            SkipPim                         = $SkipPim
                            SkipLock                        = $SkipLock
                            SkipPolicy                      = $SkipPolicy
                            SkipRole                        = $SkipRole
                            SkipResource                    = $SkipResource
                            SkipChildResource               = $SkipChildResource
                            SkipResourceType                = $SkipResourceType
                            IncludeResourcesInResourceGroup = $IncludeResourcesInResourceGroup
                            IncludeResourceType             = $IncludeResourceType
                            MaxRetryCount                   = $maxRetryCount
                            BackoffMultiplier               = $backoffMultiplier
                            runspace_AzOpsAzManagementGroup = $script:AzOpsAzManagementGroup
                            runspace_AzOpsSubscriptions     = $script:AzOpsSubscriptions
                            runspace_AzOpsPartialRoot       = $script:AzOpsPartialRoot
                            runspace_AzOpsResourceProvider  = $script:AzOpsResourceProvider
                            resources                       = $resources
                        }
                        #endregion Prepare Input Data for parallel processing

                        #region Discover child resources, pim, policies and roles in resource groups in parallel
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

                            #region Process Privileged Identity Management resources, Policies, Locks and Roles at RG scope
                            if ((-not $using:SkipPim) -or (-not $using:SkipPolicy) -or (-not $using:SkipRole) -or (-not $using:SkipLock)) {
                                & $azOps {
                                    $rgScopeObject = New-AzOpsScope -Scope $resourceGroup.ResourceId -StatePath $runspaceData.Statepath -ErrorAction Stop
                                    if (-not $using:SkipLock) {
                                        Get-AzOpsResourceLock -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                                    }
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

                            if (-not $using:SkipResource -and -not $using:SkipChildResource) {
                                $resources = $runspaceData.resources | Where-Object {$_.resourceGroup -eq $resourceGroup.name}
                                $tempExportPath = [System.IO.Path]::GetTempPath() + $resourceGroup.name + '.json'
                                # Loop through resources and convert to AzOpsState
                                foreach ($resource in $resources) {
                                    # Convert resources to AzOpsState
                                    try {
                                        & $azOps {
                                            $exportParameters = @{
                                                Resource                = $resource.ResourceId
                                                ResourceGroupName       = $resourceGroup.name
                                                SkipAllParameterization = $true
                                                Path                    = $tempExportPath
                                                DefaultProfile          = $Context | Select-Object -First 1
                                            }
                                            Invoke-AzOpsScriptBlock -ArgumentList $exportParameters -ScriptBlock {
                                                param (
                                                    $ExportParameters
                                                )
                                                $param = $ExportParameters | Write-Output
                                                Export-AzResourceGroup @param -Confirm:$false -Force -ErrorAction Stop | Out-Null
                                            } -RetryCount $runspaceData.MaxRetryCount -RetryWait $runspaceData.BackoffMultiplier -RetryType Exponential
                                        }
                                        $exportResources = (Get-Content -Path $tempExportPath | ConvertFrom-Json).resources
                                        foreach ($exportResource in $exportResources) {
                                            if (-not(($resource.name -eq $exportResource.name) -and ($resource.type -eq $exportResource.type))) {
                                                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.Processing.ChildResource' -StringValues $exportResource.name, $resourceGroup.name -Target $exportResource
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
                                        Write-PSFMessage -Level Warning @msgCommon -String 'Get-AzOpsResourceDefinition.ChildResource.Warning' -StringValues $resourceGroup.name, $_
                                    }
                                }
                                if (Test-Path -Path $tempExportPath) {
                                    Remove-Item -Path $tempExportPath
                                }
                            }
                            else {
                                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.SkippingChildResource' -StringValues $resourceGroup.name
                            }
                        }
                        #endregion Discover child resources, pim, policies and roles in resource groups in parallel
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
            subscriptions { ConvertFrom-TypeSubscription -ScopeObject $scopeObject -StatePath $StatePath -ExportRawTemplate:$ExportRawTemplate -Context $context -SkipResourceGroup:$SkipResourceGroup -SkipResource:$SkipResource -SkipResourceType:$SkipResourceType -SkipPim:$SkipPim -SkipLock:$SkipLock -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -ODataFilter $odataFilter -IncludeResourceType $IncludeResourceType -IncludeResourcesInResourceGroup $IncludeResourcesInResourceGroup }
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

        #region Process ResourceLock
        if (-not $SkipLock) {
            Get-AzOpsResourceLock -ScopeObject $scopeObject -StatePath $StatePath
        }
        #endregion Process ResourceLock

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
