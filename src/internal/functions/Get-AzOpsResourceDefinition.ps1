function Get-AzOpsResourceDefinition {

    <#
        .SYNOPSIS
            This cmdlet discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Privileged Identity Management resources, Policies, Role Assignments) from the provided input scope.
        .DESCRIPTION
            This cmdlet discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Privileged Identity Management resources, Policies, Role Assignments) from the provided input scope.
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

        [Parameter(Mandatory = $false)]
        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    begin {
        # Set variables for retry with exponential backoff
        $backoffMultiplier = 2
        $maxRetryCount = 3
        # Prepare Input Data for parallel processing
        $runspaceData = @{
            AzOpsPath                       = "$($script:ModuleRoot)\AzOps.psd1"
            StatePath                       = $StatePath
            runspace_AzOpsAzManagementGroup = $script:AzOpsAzManagementGroup
            runspace_AzOpsSubscriptions     = $script:AzOpsSubscriptions
            runspace_AzOpsPartialRoot       = $script:AzOpsPartialRoot
            runspace_AzOpsResourceProvider  = $script:AzOpsResourceProvider
            BackoffMultiplier               = $backoffMultiplier
            MaxRetryCount                   = $maxRetryCount
        }
    }

    process {
        Write-PSFMessage -Level Important -String 'Get-AzOpsResourceDefinition.Processing' -StringValues $Scope
        try {
            $scopeObject = New-AzOpsScope -Scope $Scope -StatePath $StatePath -ErrorAction Stop
            # Logging output metadata
            $msgCommon = @{
                FunctionName = 'Get-AzOpsResourceDefinition'
                Target       = $ScopeObject
            }
        }
        catch {
            Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.Processing.NotFound' -StringValues $Scope
            return
        }
        if ($scopeObject.Type -notin 'subscriptions', 'managementGroups') {
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Finished' -StringValues $scopeObject.Scope
            return
        }
        switch ($scopeObject.Type) {
            subscriptions {
                Write-PSFMessage -Level Important @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.Processing' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
                $subscriptions = Get-AzSubscription -SubscriptionId $scopeObject.Name | Where-Object { "/subscriptions/$($_.Id)" -in $script:AzOpsSubscriptions.id }
            }
            managementGroups {
                Write-PSFMessage -Level Important @msgCommon -String 'Get-AzOpsResourceDefinition.ManagementGroup.Processing' -StringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup
                $query = "resourcecontainers | where type == 'microsoft.management/managementgroups' | order by ['id'] asc"
                $managementgroups = Search-AzOpsAzGraph -ManagementGroupName $scopeObject.Name -Query $query -ErrorAction Stop | Where-Object { $_.id -in $script:AzOpsAzManagementGroup.Id }
                $subscriptions = Get-AzOpsNestedSubscription -Scope $scopeObject.Name
                if ($managementgroups) {
                    # Process managementGroup scope in parallel
                    $managementgroups | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                        $managementgroup = $_
                        $runspaceData = $using:runspaceData

                        Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                        $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru

                        & $azOps {
                            $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                            $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                            $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                            $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                        }
                        # Process Privileged Identity Management resources, Policies and Roles at managementGroup scope
                        if ((-not $using:SkipPim) -or (-not $using:SkipPolicy) -or (-not $using:SkipRole)) {
                            & $azOps {
                                $ScopeObject = New-AzOpsScope -Scope $managementgroup.id -StatePath $runspaceData.Statepath -ErrorAction Stop
                                if (-not $using:SkipPim) {
                                    Get-AzOpsPim -ScopeObject $ScopeObject -StatePath $runspaceData.Statepath
                                }
                                if (-not $using:SkipPolicy) {
                                    $policyExemptions = Get-AzOpsPolicyExemption -ScopeObject $ScopeObject
                                    if ($policyExemptions) {
                                        $policyExemptions | ConvertTo-AzOpsState -StatePath $runspaceData.Statepath
                                    }
                                }
                                if (-not $using:SkipRole) {
                                    Get-AzOpsRole -ScopeObject $ScopeObject -StatePath $runspaceData.Statepath
                                }
                            }
                        }
                    }
                }
            }
        }
        #region Process Policies at $scopeObject
        if (-not $SkipPolicy) {
            Get-AzOpsPolicy -ScopeObject $scopeObject -Subscription $subscriptions -StatePath $StatePath
        }
        #endregion Process Policies at $scopeObject

        #region Process subscription scope in parallel
        if ($subscriptions) {
            $subscriptions | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                $subscription = $_
                $runspaceData = $using:runspaceData

                Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru

                & $azOps {
                    $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                    $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                    $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                    $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                }
                # Process Privileged Identity Management resources, Policies, Locks and Roles at subscription scope
                if ((-not $using:SkipPim) -or (-not $using:SkipPolicy) -or (-not $using:SkipLock) -or (-not $using:SkipRole)) {
                    & $azOps {
                        $scopeObject = New-AzOpsScope -Scope ($subscription.Type + '/' + $subscription.Id) -StatePath $runspaceData.Statepath -ErrorAction Stop
                        if (-not $using:SkipPim) {
                            Get-AzOpsPim -ScopeObject $scopeObject -StatePath $runspaceData.Statepath
                        }
                        if (-not $using:SkipPolicy) {
                            $policyExemptions = Get-AzOpsPolicyExemption -ScopeObject $scopeObject
                            if ($policyExemptions) {
                                $policyExemptions | ConvertTo-AzOpsState -StatePath $runspaceData.Statepath
                            }
                        }
                        if (-not $using:SkipLock) {
                            Get-AzOpsResourceLock -ScopeObject $scopeObject -StatePath $runspaceData.Statepath
                        }
                        if (-not $using:SkipRole) {
                            Get-AzOpsRole -ScopeObject $scopeObject -StatePath $runspaceData.Statepath
                        }
                    }
                }
            }
        }
        #endregion Process subscription scope in parallel

        #region Process Resource Groups
        if ($SkipResourceGroup -or (-not $subscriptions)) {
            if ($SkipResourceGroup) {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SkippingResourceGroup'
            }
            else {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Subscription.NotFound'
            }
        }
        else {
            if ((Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') -ne '*') {
                $subscriptionsToIncludeResourceGroups = $subscriptions | Where-Object { $_.Id -in (Get-PSFConfigValue -FullName 'AzOps.Core.SubscriptionsToIncludeResourceGroups') }
            }
            $query = "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups' | where managedBy == '' | order by ['id'] asc"
            if ($subscriptionsToIncludeResourceGroups) {
                $resourceGroups = Search-AzOpsAzGraph -Subscription $subscriptionsToIncludeResourceGroups -Query $query -ErrorAction Stop
            }
            else {
                $resourceGroups = Search-AzOpsAzGraph -Subscription $subscriptions -Query $query -ErrorAction Stop
            }
            if ($resourceGroups) {
                # Process Resource Groups in parallel
                $resourceGroups | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                    $resourceGroup = $_
                    $runspaceData = $using:runspaceData

                    Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                    $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru

                    & $azOps {
                        $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                        $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                        $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                        $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                    }
                    # Create Resource Group in file system
                    & $azOps {
                        ConvertTo-AzOpsState -Resource $resourceGroup -StatePath $runspaceData.Statepath
                    }
                    # Process Privileged Identity Management resources, Policies, Locks and Roles at resource group scope
                    if ((-not $using:SkipPim) -or (-not $using:SkipPolicy) -or (-not $using:SkipRole) -or (-not $using:SkipLock)) {
                        & $azOps {
                            $rgScopeObject = New-AzOpsScope -Scope $resourceGroup.id -StatePath $runspaceData.Statepath -ErrorAction Stop
                            if (-not $using:SkipLock) {
                                Get-AzOpsResourceLock -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                            }
                            if (-not $using:SkipPim) {
                                Get-AzOpsPim -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                            }
                            if (-not $using:SkipPolicy) {
                                $policyExemptions = Get-AzOpsPolicyExemption -ScopeObject $rgScopeObject
                                if ($policyExemptions) {
                                    $policyExemptions | ConvertTo-AzOpsState -StatePath $runspaceData.Statepath
                                }
                            }
                            if (-not $using:SkipRole) {
                                Get-AzOpsRole -ScopeObject $rgScopeObject -StatePath $runspaceData.Statepath
                            }
                        }
                    }
                }
            }
            else {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.NoResourceGroup' -StringValues $scopeObject.Name
            }
            # Process Policies at Resource Group scope
            if (-not $SkipPolicy) {
                if ($subscriptionsToIncludeResourceGroups) {
                    Get-AzOpsPolicy -ScopeObject $scopeObject -Subscription $subscriptions -SubscriptionsToIncludeResourceGroups $subscriptionsToIncludeResourceGroups -ResourceGroup -StatePath $StatePath
                }
                else {
                    Get-AzOpsPolicy -ScopeObject $scopeObject -Subscription $subscriptions -ResourceGroup -StatePath $StatePath
                }
            }
            # Process Resources at Resource Group scope
            if (-not $SkipResource) {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Processing.Resource.Discovery' -StringValues $scopeObject.Name
                try {
                    $SkipResourceType | ForEach-Object { $skipResourceTypes += ($(if($skipResourceTypes){","}) + "'" + $_  + "'") }
                    $query = "resources | where type !in~ ($skipResourceTypes)"
                    if ($IncludeResourceType -ne "*") {
                        $IncludeResourceType | ForEach-Object { $includeResourceTypes += ($(if($includeResourceTypes){","}) + "'" + $_  + "'") }
                        $query = $query + " and type in~ ($includeResourceTypes)"
                    }
                    if ($IncludeResourcesInResourceGroup -ne "*") {
                        $IncludeResourcesInResourceGroup | ForEach-Object { $includeResourcesInResourceGroups += ($(if($includeResourcesInResourceGroups){","}) + "'" + $_  + "'") }
                        $query = $query + " and resourceGroup in~ ($includeResourcesInResourceGroups)"
                    }
                    $query = $query + " | order by ['id'] asc"
                    $resourcesBase = Search-AzOpsAzGraph -Subscription $subscriptions -Query $query -ErrorAction Stop
                }
                catch {
                    Write-PSFMessage -Level Warning @msgCommon -String 'Get-AzOpsResourceDefinition.Processing.Resource.Warning' -StringValues $scopeObject.Name
                }
                if ($resourcesBase) {
                    $resources = @()
                    foreach ($resource in $resourcesBase) {
                        if ($resourceGroups | Where-Object { $_.name -eq $resource.resourceGroup -and $_.subscriptionId -eq $resource.subscriptionId }) {
                            Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Processing.Resource' -StringValues $resource.name, $resource.resourcegroup -Target $resource
                            $resources += $resource
                            ConvertTo-AzOpsState -Resource $resource -StatePath $Statepath
                        }
                    }
                }
                else {
                    Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Processing.Resource.Discovery.NotFound' -StringValues $scopeObject.Name
                }
            }
            else {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SkippingResources'
            }
            # Process resources as scope in parallel, look for childResource
            if (-not $SkipResource -and -not $SkipChildResource) {
                $resources | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                    $resource = $_
                    $runspaceData = $using:runspaceData

                    Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                    $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru

                    & $azOps {
                        $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                        $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                        $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                        $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                    }
                    $context = Get-AzContext
                    $context.Subscription.Id = $resource.subscriptionId
                    $tempExportPath = [System.IO.Path]::GetTempPath() + (New-Guid).ToString() + '.json'
                    try {
                        & $azOps {
                            $exportParameters = @{
                                Resource                = $resource.id
                                ResourceGroupName       = $resource.resourceGroup
                                SkipAllParameterization = $true
                                Path                    = $tempExportPath
                                DefaultProfile          = $context | Select-Object -First 1
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
                        $resourceGroup = $using:resourceGroups | Where-Object {$_.subscriptionId -eq $resource.subscriptionId -and $_.name -eq $resource.resourceGroup}
                        foreach ($exportResource in $exportResources) {
                            if (-not(($resource.name -eq $exportResource.name) -and ($resource.type -eq $exportResource.type))) {
                                Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.ChildResource' -StringValues $exportResource.name, $resource.resourceGroup -Target $exportResource
                                $ChildResource = @{
                                    resourceProvider = $exportResource.type -replace '/', '_'
                                    resourceName     = $exportResource.name -replace '/', '_'
                                    parentResourceId = $resourceGroup.id
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
                        Write-PSFMessage -Level Warning -String 'Get-AzOpsResourceDefinition.ChildResource.Warning' -StringValues $resource.resourceGroup, $_
                    }
                    if (Test-Path -Path $tempExportPath) {
                        Remove-Item -Path $tempExportPath
                    }
                }
            }
            else {
                Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.SkippingChildResources'
            }
        }
        #endregion Process Resource Groups
        Write-PSFMessage -Level Verbose @msgCommon -String 'Get-AzOpsResourceDefinition.Finished' -StringValues $scopeObject.Scope
    }
}