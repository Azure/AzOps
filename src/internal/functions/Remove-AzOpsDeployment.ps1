function Remove-AzOpsDeployment {
    <#
        .SYNOPSIS
            Deletion of supported resource types from azure according to AzOps.Core.DeletionSupportedResourceType.
        .DESCRIPTION
            Deletion of supported resource types from azure according to AzOps.Core.DeletionSupportedResourceType.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the ARM parameters templates can be found.
        .PARAMETER StatePath
            The root folder under which to find the resource json.
        .PARAMETER DeletionSupportedResourceType
            Supported resource types for deletion.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > $AzOpsRemovalList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment
            Remove all unique deployments provided from $AzOpsRemovalList
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateFilePath = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate'),

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateParameterFilePath,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [object[]]
        $DeletionSupportedResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.DeletionSupportedResourceType')
    )

    process {
        function Get-AzLocksDeletionDependency {
            param (
                $resourceToDelete
            )
            $dependency = @()
            if ($resourceToDelete.ResourceType -in $DeletionSupportedResourceType) {
                if ($resourceToDelete.SubscriptionId) {
                    $depLock = Get-AzResourceLock -Scope "/subscriptions/$($resourceToDelete.SubscriptionId)"
                    if ($depLock) {
                        foreach ($lock in $depLock) {
                            if ($lock.ResourceGroupName -eq $resourceToDelete.ResourceGroupName) {
                                #Filter through each return and validate resource is not at child resource scope
                                if ($lock.ResourceId -notlike '*/resourcegroups/*/providers/*/providers/*') {
                                    $dependency += [PSCustomObject]@{
                                        ResourceType = 'locks'
                                        ResourceId = $lock.ResourceId
                                    }
                                }
                            }
                            elseif ($lock.ResourceId -notlike '*/resourcegroups/*') {
                                $dependency += [PSCustomObject]@{
                                    ResourceType = 'locks'
                                    ResourceId = $lock.ResourceId
                                }
                            }
                        }
                    }
                    if ($dependency) {
                        $dependency = $dependency | Sort-Object ResourceId -Unique
                        return $dependency
                    }
                }
            }
        }
        function Get-AzPolicyAssignmentDeletionDependency {
            param (
                $resourceToDelete
            )
            $dependency = @()
            if ($resourceToDelete.ResourceType -in $DeletionSupportedResourceType) {
                switch ($resourceToDelete.ResourceType) {
                    'Microsoft.Authorization/policyAssignments' {
                        $depPolicyAssignment = $resourceToDelete
                    }
                    'Microsoft.Authorization/policyDefinitions' {
                        $depPolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $resourceToDelete.PolicyDefinitionId -ErrorAction SilentlyContinue
                    }
                    'Microsoft.Authorization/policySetDefinitions' {
                        $query = "PolicyResources | where type == 'microsoft.authorization/policyassignments' and properties.policyDefinitionId == '$($resourceToDelete.PolicySetDefinitionId)' | order by id asc"
                        $depPolicyAssignment = Search-AzGraphDeletionDependency -query $query
                        if ($depPolicyAssignment) {
                            #Loop through each return from graph cache and validate resource is still present in Azure
                            $depPolicyAssignment = foreach ($policyAssignment in $depPolicyAssignment) {Get-AzPolicyAssignment -Id $policyAssignment.Id -ErrorAction SilentlyContinue}
                        }
                    }
                }
            }
            if ($depPolicyAssignment) {
                foreach ($policyAssignment in $depPolicyAssignment) {
                    $dependency += [PSCustomObject]@{
                        ResourceType = $policyAssignment.ResourceType
                        ResourceId = $policyAssignment.ResourceId
                    }
                    if ($policyAssignment.Identity.IdentityType -eq 'SystemAssigned') {
                        $depSystemAssignedRoleAssignment = $null
                        $depSystemAssignedRoleAssignment = Get-AzRoleAssignment -ObjectId $policyAssignment.Identity.PrincipalId -Scope $policyAssignment.Properties.Scope
                        if ($depSystemAssignedRoleAssignment) {
                            foreach ($roleAssignmentId in $depSystemAssignedRoleAssignment.RoleAssignmentId) {
                                #Filter through each return and validate resource is not at child resource scope
                                if ($roleAssignmentId -notlike '*/resourcegroups/*/providers/*/providers/*') {
                                    $dependency += [PSCustomObject]@{
                                        ResourceType = 'roleAssignments'
                                        ResourceId = $roleAssignmentId
                                    }
                                }
                                else {
                                    Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.ResourceDependencyNested' -StringValues $roleAssignmentId, $policyAssignment.ResourceId
                                }
                            }
                        }
                    }
                }
            }
            if ($dependency) {
                $dependency = $dependency | Sort-Object ResourceId -Unique | Where-Object {$_.ResourceId -ne $resourceToDelete.ResourceId}
                return $dependency
            }
        }
        function Get-AzPolicyDefinitionDeletionDependency {
            param (
                $resourceToDelete
            )
            if ($resourceToDelete.ResourceType -eq 'Microsoft.Authorization/policyDefinitions') {
                $dependency = @()
                $query = "PolicyResources | where type == 'microsoft.authorization/policysetdefinitions' and properties.policyType == 'Custom' | project id, type, policyDefinitions = (properties.policyDefinitions) | mv-expand policyDefinitions | project id, type, policyDefinitionId = tostring(policyDefinitions.policyDefinitionId) | where policyDefinitionId == '$($resourceToDelete.PolicyDefinitionId)' | order by policyDefinitionId asc | order by id asc"
                $depPolicySetDefinition = Search-AzGraphDeletionDependency -query $query
                if ($depPolicySetDefinition) {
                    $depPolicySetDefinition = foreach ($policySetDefinition in $depPolicySetDefinition) {
                        #Loop through each return from graph cache and validate resource is still present in Azure
                        $policy = Get-AzPolicySetDefinition -Id $policySetDefinition.Id -ErrorAction SilentlyContinue
                        if ($policy) {
                            $dependency += [PSCustomObject]@{
                                ResourceType = $policy.ResourceType
                                ResourceId = $policy.PolicySetDefinitionId
                            }
                            $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $policy
                        }
                    }
                }
                if ($dependency) {
                    $dependency = $dependency | Sort-Object ResourceId -Unique | Where-Object {$_.ResourceId -ne $resourceToDelete.ResourceId}
                    return $dependency
                }
            }
        }
        function Search-AzGraphDeletionDependency {
            param (
                $query,

                $PartialMgDiscoveryRoot = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot')
            )
            $results = @()
            if ($PartialMgDiscoveryRoot) {
                foreach ($managementRoot in $PartialMgDiscoveryRoot) {
                    $subscriptions = Get-AzOpsNestedSubscription -Scope $managementRoot
                    $results += Search-AzOpsAzGraph -ManagementGroupName $managementRoot -Query $query -ErrorAction Stop
                    if ($subscriptions) {
                        $results += Search-AzOpsAzGraph -Subscription $subscriptions -Query $query -ErrorAction Stop
                    }
                }
            }
            else {
                $results = Search-AzOpsAzGraph -Query $query -UseTenantScope -ErrorAction Stop
            }
            if ($results) {
                $results = $results | Sort-Object Id -Unique
                return $results
            }
        }
        $dependencyMissing = $null
        #Adjust TemplateParameterFilePath to compensate for policyDefinitions and policySetDefinitions usage of parameters.json
        if ($TemplateParameterFilePath) {
            $TemplateFilePath = $TemplateParameterFilePath
        }
        #Deployment Name
        $fileItem = Get-Item -Path $TemplateFilePath
        $removeJobName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
        $removeJobName = "AzOps-RemoveResource-$removeJobName"
        Write-PSFMessage -Level Important -String 'Remove-AzOpsDeployment.Processing' -StringValues $removeJobName, $TemplateFilePath -Target $TemplateFilePath
        #region Parse Content
        $templateContent = Get-Content $TemplateFilePath | ConvertFrom-Json -AsHashtable
        #endregion
        #region Validate it is AzOpsgenerated template
        $schemavalue = '$schema'
        if ($templateContent.metadata._generator.name -eq "AzOps" -or $templateContent.$schemavalue -like "*deploymentParameters.json#") {
            Write-PSFMessage -Level Verbose -Message 'Remove-AzOpsDeployment.Metadata.Success' -StringValues $TemplateFilePath -Target $TemplateFilePath
        }
        else {
            Write-PSFMessage -Level Error -Message 'Remove-AzOpsDeployment.Metadata.Failed' -StringValues $TemplateFilePath -Target $TemplateFilePath
            return
        }
        #endregion Validate it is AzOpsgenerated template
        #region Resolve Scope
        try {
            $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
        }
        catch {
            Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.Scope.Failed' -Target $TemplateFilePath -StringValues $TemplateFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.Scope.Empty' -Target $TemplateFilePath -StringValues $TemplateFilePath
            return
        }
        #endregion Resolve Scope

        #region SetContext
        Set-AzOpsContext -ScopeObject $scopeObject
        #endregion SetContext

        #region remove supported resources
        if ($scopeObject.Resource -in $DeletionSupportedResourceType) {
            $dependency = @()
            switch ($scopeObject.Resource) {
                # Check resource existance through optimal path
                'locks' {
                    $resourceToDelete = Get-AzResourceLock -Scope "/subscriptions/$($ScopeObject.Subscription)" -ErrorAction SilentlyContinue | Where-Object {$_.ResourceID -eq $ScopeObject.scope}
                }
                'policyAssignments' {
                    $resourceToDelete = Get-AzPolicyAssignment -Id $scopeObject.scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policyDefinitions' {
                    $resourceToDelete = Get-AzPolicyDefinition -Id $scopeObject.scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzPolicyDefinitionDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policyExemptions' {
                    $resourceToDelete = Get-AzPolicyExemption -Id $scopeObject.scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policySetDefinitions' {
                    $resourceToDelete = Get-AzPolicySetDefinition -Id $scopeObject.scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'roleAssignments' {
                    $resourceToDelete = Invoke-AzRestMethod -Path "$($scopeObject.scope)?api-version=2022-01-01-preview" | Where-Object { $_.StatusCode -eq 200 }
                    if ($resourceToDelete) {
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
            }
            # If no resource to delete was found return
            if (-not $resourceToDelete) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.ResourceNotFound' -StringValues $scopeObject.Resource, $scopeObject.Scope -Target $scopeObject
                $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $scopeObject.scope, [environment]::NewLine
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            if ($dependency) {
                foreach ($resource in $dependency) {
                    if ($resource.ResourceId -notin $deletionList.ScopeObject.Scope) {
                        Write-PSFMessage -Level Critical -String 'Remove-AzOpsDeployment.ResourceDependencyNotFound' -StringValues $resource.ResourceId, $scopeObject.Scope -Target $scopeObject
                        $results = 'Missing resource dependency:{2}{0} for successful deletion of {1}.{2}{2}Please add dependent resource to pull request and retry.' -f $resource.ResourceId, $scopeObject.scope, [environment]::NewLine
                        Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                        $dependencyMissing = [PSCustomObject]@{
                            dependencyMissing = $true
                        }
                    }
                }
            }
            else {
                $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $scopeObject.scope, [environment]::NewLine
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            if ($dependencyMissing) {
                return $dependencyMissing
            }
            elseif ($dependency) {
                $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $scopeObject.scope, [environment]::NewLine
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            if ($PSCmdlet.ShouldProcess("Remove $($scopeObject.Scope)?")) {
                $null = Remove-AzResource -ResourceId $scopeObject.Scope -Force
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
    }
}