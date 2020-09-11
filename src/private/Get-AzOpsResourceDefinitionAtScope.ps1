<#
.SYNOPSIS
    This cmdlet recursively discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Policies, Role Assignments) from the provided input scope.
.DESCRIPTION
    This cmdlet recursively discovers resources (Management Groups, Subscriptions, Resource Groups, Resources, Policies, Role Assignments) from the provided input scope.
.EXAMPLE
    # Discover all resources from root Management Group
    $TenantRootId = '/providers/Microsoft.Management/managementGroups/{0}' -f (Get-AzTenant).Id
    Get-AzOpsResourceDefinitionAtScope -scope $TenantRootId -Verbose
.EXAMPLE
    # Discover all resources from child Management Group, skip discovery of policies and resource groups
    Get-AzOpsResourceDefinitionAtScope -scope /providers/Microsoft.Management/managementGroups/landingzones -SkipPolicy -SkipResourceGroup
.EXAMPLE
    # Discover all resources from Subscription level
    Get-AzOpsResourceDefinitionAtScope -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c
.EXAMPLE
    # Discover all resources from resource group level
    Get-AzOpsResourceDefinitionAtScope -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c/resourceGroups/myresourcegroup
.EXAMPLE
    # Discover a single resource
    Get-AzOpsResourceDefinitionAtScope -scope /subscriptions/623625ae-cfb0-4d55-b8ab-0bab99cbf45c/resourceGroups/contoso-global-dns/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net
.INPUTS
    Discovery scope - supported scopes:
    - Management Groups
    - Subscriptions
    - Resource Groups
    - Resources
.OUTPUTS
    State file representing each discovered resource in the .AzState folder
    Example: .AzState\Microsoft.Network_privateDnsZones-privatelink.database.windows.net.parameters.json
#>

function Get-AzOpsResourceDefinitionAtScope {

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsState')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsStateConfig')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsAzManagementGroup')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSubscriptions')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsThrottleLimit')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsExportRawTemplate')]
    [CmdletBinding()]
    [OutputType()]
    param (
        # Discovery scope - input validation
        [Parameter(Mandatory = $true)]
        $scope,
        # Skip discovery of policies for better performance.
        [Parameter(Mandatory = $false)]
        [switch]$SkipPolicy,
        # Skip discovery of policies for better performance.
        [Parameter(Mandatory = $false)]
        [switch]$SkipRole,
        # Skip discovery of resource groups and resources for better performance.
        [Parameter(Mandatory = $false)]
        [switch]$SkipResourceGroup
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsResourceDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        # Set variables for retry with exponential backoff
        [Int]$backoffMultiplier = 2
        [Int]$maxRetryCount = 6
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsResourceDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing AzOpsResourceDefinitionAtScope [$scope]"
        # Get AzOpsScope for inputscope
        $scope = (New-AzOpsScope -scope $scope -ErrorAction SilentlyContinue)

        # Continue if scope exists (added since management group api returns disabled/inaccesible subscriptions)
        if ($scope) {

            # Scope contains Subscription (Subscription > Resource Group > Resource)
            if ($scope.subscription) {
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Found Subscription: $($scope.subscriptionDisplayName) ($($scope.subscription))"
                # Define variable with AzContext for later use in -DefaultProfile parameter
                $context = Get-AzContext -ListAvailable | Where-Object { $_.Subscription.id -eq $scope.subscription }
                # Define variable with Odatafilter to use in Get-AzResourceGroup and Get-AzResource
                $OdataFilter = '$filter=subscriptionId eq ' + "'$($scope.subscription)'"
                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Setting Odatafilter: $OdataFilter"
            }

            # Process supported scopes
            switch ($scope.Type) {
                # Process resources
                'resource' {
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Resource [$($scope.resource)] in Resource Group [$($scope.resourcegroup)]"
                    # Get resource
                    $resource = Get-AzResource -ResourceId $scope.scope -ErrorAction:Continue
                    if ($resource) {
                        # Convert resource to AzOpsState
                        ConvertTo-AzOpsState -resource $resource
                    }
                    else {
                        Write-AzOpsLog -Level Warning -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Unable to process Resource [$($scope.resource)] in Resource Group [$($scope.resourcegroup)]"
                    }
                }
                # Process resource groups
                'resourcegroups' {
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Resource Group [$($scope.resourcegroup)] in Subscription [$($scope.subscriptionDisplayName)] ($($scope.subscription))"
                    if ($null -eq $rg.ManagedBy) {
                        # Get resource group
                        $rg = (Get-AzResourceGroup -Name $scope.resourcegroup -DefaultProfile $context)
                        ConvertTo-AzOpsState -resourceGroup $rg
                        # Get all resources in resource groups
                        $Resources = Get-AzResource -DefaultProfile $context -ResourceGroupName $rg.ResourceGroupName -ODataQuery $OdataFilter -ExpandProperties
                        foreach ($Resource in $Resources) {
                            # Convert resources to AzOpsState
                            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Resource [$($resource.Name)] in Resource Group [$($resource.ResourceGroupName)]"
                            ConvertTo-AzOpsState -resource $resource
                        }
                    }
                    else {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Skipping $($rg.ResourceGroupName) as it is managed by $($rg.ManagedBy)"
                    }
                }
                # Process subscriptions
                'subscriptions' {
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Subscription [$($scope.subscriptionDisplayName)] ($($scope.subscription))"
                    # Skip discovery of resource groups if SkipResourceGroup switch have been used
                    # Separate discovery of resource groups in subscriptions to support parallel discovery
                    if ($true -eq $SkipResourceGroup) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "SkipResourceGroup switch used, skipping Resource Group discovery"
                    }
                    else {
                        # Get all Resource Groups in Subscription
                        # Retry loop with exponential backoff implemented to catch errors
                        # Introduced due to error "Your Azure Credentials have not been set up or expired"
                        # https://github.com/Azure/azure-powershell/issues/9448
                        # Define variables used by script
                        $retryCount = 0
                        do {
                            try {
                                $retryCount++
                                $ResourceGroups = Get-AzResourceGroup -DefaultProfile $context `
                                    -ErrorAction Stop `
                                | Where-Object -Filterscript { -not($_.Managedby) }
                                if ($null -eq $ResourceGroups) {
                                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "No Resources Groups found in Subscription [$($scope.subscriptionDisplayName)] ($($scope.subscription))"
                                    break
                                }
                            }
                            catch {
                                if ($retryCount -lt $maxRetryCount) {
                                    $sleepTimeInSeconds = [math]::Pow($backoffMultiplier, $retryCount)
                                    Write-AzOpsLog -Level Warning -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Caught error finding Resource Groups (retryCount=$retryCount). Waiting for $sleepTimeInSeconds seconds"
                                    Start-Sleep -Seconds $sleepTimeInSeconds
                                }
                                elseif ($retryCount -ge $maxRetryCount) {
                                    Write-AzOpsLog -Level Warning -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Timeout exporting Resource Groups from Subscription $($context.Subscription.Id)"
                                    Write-AzOpsLog -Level Error -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "$($_.Exception.Message | Out-String)"
                                    break
                                }
                            }
                        } until ($ResourceGroups)

                        # Discover all resource groups in parallel
                        $ResourceGroups | Foreach-Object -ThrottleLimit 10 -Parallel {

                            # region Importing module
                            # We need to import all required modules and declare variables again because of the parallel runspaces
                            # https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/

                            $RootPath = (Split-Path $using:PSScriptRoot -Parent)
                            Import-Module $RootPath/AzOps.psd1 -Force
                            Get-ChildItem -Path $RootPath\private -Include *.ps1 -Recurse -Force | ForEach-Object { . $_.FullName }

                            $global:AzOpsState = $using:global:AzOpsState
                            $global:AzOpsStateConfig = $using:global:AzOpsStateConfig
                            $global:AzOpsAzManagementGroup = $using:global:AzOpsAzManagementGroup
                            $global:AzOpsSubscriptions = $using:global:AzOpsSubscriptions
                            $global:AzOpsThrottleLimit = $using:Global:AzOpsThrottleLimit
                            $global:AzOpsExportRawTemplate = $using:Global:AzOpsExportRawTemplate
                            $global:AzOpsGeneralizeTemplates = $using:Global:AzOpsGeneralizeTemplates

                            $OdataFilter = $using:OdataFilter
                            $backoffMultiplier = $using:backoffMultiplier
                            $maxRetryCount = $using:maxRetryCount

                            # endregion

                            $context = Get-AzContext -ListAvailable | Where-Object { $_.Subscription.id -eq $scope.subscription }

                            # Convert resource group to AzOps-state.
                            $rg = $_
                            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Resource Group [$($rg.ResourceGroupName)]"
                            ConvertTo-AzOpsState -ResourceGroup $rg

                            # Retry loop with exponential backoff implemented to catch errors
                            # Introduced due to error "Your Azure Credentials have not been set up or expired"
                            # https://github.com/Azure/azure-powershell/issues/9448
                            $retryCount = 0
                            do {
                                try {
                                    $retryCount++
                                    $Resources = Get-AzResource -DefaultProfile $context `
                                        -ResourceGroupName $rg.ResourceGroupName `
                                        -ODataQuery $OdataFilter `
                                        -ExpandProperties `
                                        -ErrorAction Stop
                                    if ($null -eq $Resources) {
                                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "No Resources found in Resource Group [$($rg.ResourceGroupName)]"
                                        break
                                    }
                                }
                                catch {
                                    if ($retryCount -lt $maxRetryCount) {
                                        $sleepTimeInSeconds = [math]::Pow($backoffMultiplier, $retryCount)
                                        Write-AzOpsLog -Level Warning -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Caught error finding Resources (retryCount=$retryCount). Waiting for $sleepTimeInSeconds seconds"
                                        Start-Sleep -Seconds $sleepTimeInSeconds
                                    }
                                    elseif ($retryCount -ge $maxRetryCount) {
                                        Write-AzOpsLog -Level Warning -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Timeout exporting Resources from Resource Group [$($rg.ResourceGroupName)]"
                                        Write-AzOpsLog -Level Error -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "$($_.Exception.Message | Out-String)"
                                        break
                                    }
                                }
                            } until ($Resources)

                            # Loop through resources and convert them to AzOpsState
                            foreach ($Resource in $Resources) {
                                # Convert resources to AzOpsState
                                Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Resource [$($resource.Name)] in Resource Group [$($resource.ResourceGroupName)]"
                                ConvertTo-AzOpsState -resource $resource
                            }
                        }
                    }
                    ConvertTo-AzOpsState -Resource (($global:AzOpsAzManagementGroup).children | Where-Object { $_ -ne $null -and $_.Name -eq $scope.name })
                }
                # Process Management Groups
                'managementGroups' {
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Management Group [$($scope.managementgroupDisplayName)] ($($scope.managementgroup))"
                    $ChildOfManagementGroups = ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }).Children
                    if ($ChildOfManagementGroups) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "$($scope.managementgroup) contains $($childofmanagementgroups.count) children"

                        $ChildOfManagementGroups | Foreach-Object -ThrottleLimit 1 -Parallel {
                            # region Importing module
                            # We need to import all required modules and declare variables again because of the parallel runspaces
                            # https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/
                            $RootPath = (Split-Path $using:PSScriptRoot -Parent)
                            Import-Module $RootPath/AzOps.psd1 -Force
                            Get-ChildItem -Path $RootPath\private -Include *.ps1 -Recurse -Force | ForEach-Object { . $_.FullName }

                            $global:AzOpsState = $using:global:AzOpsState
                            $global:AzOpsStateConfig = $using:global:AzOpsStateConfig
                            $global:AzOpsAzManagementGroup = $using:global:AzOpsAzManagementGroup
                            $global:AzOpsSubscriptions = $using:global:AzOpsSubscriptions
                            $global:AzOpsExportRawTemplate = $using:Global:AzOpsExportRawTemplate
                            $global:AzOpsThrottleLimit = $using:Global:AzOpsThrottleLimit
                            $global:AzOpsGeneralizeTemplates = $using:Global:AzOpsGeneralizeTemplates

                            $SkipPolicy = $using:SkipPolicy
                            $SkipRole = $using:SkipRole
                            $SkipResourceGroup = $using:SkipResourceGroup
                            # endregion

                            $child = $_
                            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Processing Management Group Child Resource [$($child.Id)]"
                            Get-AzOpsResourceDefinitionAtScope -scope $child.Id -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -SkipResourceGroup:$SkipResourceGroup -ErrorAction Stop -Verbose:$VerbosePreference
                        }
                    }
                    ConvertTo-AzOpsState -Resource ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup })
                }
            }
            # Process policies and policy assignments for resourcegroups, subscriptions and Management Groups
            if ($scope.Type -in 'resourcegroups', 'subscriptions', 'managementgroups' ) {
                $serializedPolicyDefinitionsInAzure = @()
                $serializedPolicySetDefinitionsInAzure = @()
                $serializedPolicyAssignmentsInAzure = @()
                $serializedRoleDefinitionsInAzure = @()
                $serializedRoleAssignmentInAzure = @()

                if (-not $SkipPolicy) {
                    # Process policy definitions
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating Policy Definition at scope $scope"
                    $currentPolicyDefinitionsInAzure = @()
                    $currentPolicyDefinitionsInAzure = Get-AzOpsPolicyDefinitionAtScope -scope $scope
                    foreach ($policydefinition in $currentPolicyDefinitionsInAzure) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating through policyset definition at scope $scope for $($policydefinition.resourceid)"
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Serializing AzOpsState for $scope at $($scope.statepath)"
                        # Convert policyDefinition to AzOpsState
                        ConvertTo-AzOpsState -CustomObject $policydefinition
                        # Serialize policyDefinition in original format and add to variable for full export
                        $serializedPolicyDefinitionsInAzure += ConvertTo-AzOpsState -Resource $policydefinition -ReturnObject -ExportRawTemplate
                    }
                    # Process policySetDefinitions (initiatives)
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating Policy Set Definition at scope $scope"
                    $currentPolicySetDefinitionsInAzure = @()
                    $currentPolicySetDefinitionsInAzure = Get-AzOpsPolicySetDefinitionAtScope -scope $scope
                    foreach ($policysetdefinition in $currentPolicySetDefinitionsInAzure) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating through policyset definition at scope $scope for $($policysetdefinition.resourceid)"
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Serializing AzOpsState for $scope at $($scope.statepath)"
                        # Convert policySetDefinition to AzOpsState
                        ConvertTo-AzOpsState -CustomObject $policysetdefinition
                        # Serialize policySetDefinition in original format and add to variable for full export
                        $serializedPolicySetDefinitionsInAzure += ConvertTo-AzOpsState -Resource $policysetdefinition -ReturnObject -ExportRawTemplate
                    }

                    # Process policy assignments
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating Policy Assignment at scope $scope"
                    $currentPolicyAssignmentInAzure = @()
                    $currentPolicyAssignmentInAzure = Get-AzOpsPolicyAssignmentAtScope -scope $scope
                    foreach ($policyAssignment in $currentPolicyAssignmentInAzure) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating through policy definitition at scope $scope for $($policyAssignment.resourceid)"
                        # Convert policyAssignment to AzOpsState
                        ConvertTo-AzOpsState -CustomObject $policyAssignment
                        # Serialize policyAssignment in original format and add to variable for full export
                        $serializedPolicyAssignmentsInAzure += ConvertTo-AzOpsState -Resource $policyAssignment -ReturnObject -ExportRawTemplate
                    }
                }
                if (-not $SkipRole) {
                    # Process role Definition
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleDefinitionAtScope" -Message "Iterating Role Definition at scope $scope"
                    $currentRoleDefinitionsInAzure = @()
                    $currentRoleDefinitionsInAzure = Get-AzOpsRoleDefinitionAtScope -scope $scope
                    foreach ($roleDefinition in $currentRoleDefinitionsInAzure) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating through role definition at scope $scope for $($roleDefinition.Id)"
                        # Convert roleAssignment to AzOpsState
                        ConvertTo-AzOpsState -CustomObject $roleDefinition
                        # Serialize roleAssignment in original format and add to variable for full export
                        $serializedRoleDefinitionsInAzure += ConvertTo-AzOpsState -Resource $roleDefinition -ReturnObject -ExportRawTemplate
                    }

                    # Process role assignment
                    Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsRoleAssignmentAtScope" -Message "Iterating Role Assignment at scope $scope"
                    $currentRoleAssignmentInAzure = @()
                    $currentRoleAssignmentInAzure = Get-AzOpsRoleAssignmentAtScope -scope $scope
                    foreach ($roleAssignment in $currentRoleAssignmentInAzure) {
                        Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Iterating through role assignment at scope $scope for $($roleAssignment.Id)"
                        # Convert roleAssignment to AzOpsState
                        ConvertTo-AzOpsState -CustomObject $roleAssignment
                        # Serialize roleAssignment in original format and add to variable for full export
                        $serializedRoleAssignmentInAzure += ConvertTo-AzOpsState -Resource $roleAssignment -ReturnObject -ExportRawTemplate
                    }
                }
                # For subscriptions and Management Groups, export all policy/policyset/policyassignments at scope in one file
                if ($scope.Type -in 'subscriptions', 'managementgroups') {
                    # Get statefile from scope
                    $parametersJson = Get-Content -Path $scope.statepath | ConvertFrom-Json -Depth 100
                    # Create property bag and add resources at scope
                    $propertyBag = [ordered]@{
                        'policyDefinitions'    = @($serializedPolicyDefinitionsInAzure)
                        'policySetDefinitions' = @($serializedPolicySetDefinitionsInAzure)
                        'policyAssignments'    = @($serializedPolicyAssignmentsInAzure)
                        'roleDefinitions'      = @($serializedRoleDefinitionsInAzure)
                        'roleAssignments'      = if ($global:AzOpsGeneralizeTemplates -eq 1) { , @() } else { , @($serializedRoleAssignmentInAzure) }
                    }
                    # Add property bag to parameters json
                    $parametersJson.parameters.input.value | Add-Member -Name 'properties' -Type NoteProperty -Value $propertyBag -force
                    # Export state file with properties at scope
                    ConvertTo-AzOpsState -Resource $parametersJson -ExportPath $scope.statepath -ExportRawTemplate
                }
            }
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Finished Processing Scope [$($scope.scope)]"
        }
        else {
            Write-AzOpsLog -Level Verbose -Topic "Get-AzOpsResourceDefinitionAtScope" -Message "Scope [$($PSBoundParameters['Scope'])] not found in Azure or it is excluded"
        }
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Get-AzOpsResourceDefinitionAtScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}
