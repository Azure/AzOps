function Remove-AzOpsDeployment {

    <#
        .SYNOPSIS
            Deletion of supported resource types AzOps.Core.DeletionSupportedResourceType and custom templates.
        .DESCRIPTION
            Deletion of supported resource types AzOps.Core.DeletionSupportedResourceType and custom templates.
        .PARAMETER CustomTemplateResourceDeletion
            Enable or disable, deletion of resources in custom templates.
        .PARAMETER DeploymentName
            Dummy name used to run Azure WhatIf deployment.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the ARM parameters templates can be found.
        .PARAMETER StatePath
            The root folder under which to find the resource json.
        .PARAMETER DeletionSupportedResourceType
            Supported resource types for deletion of AzOps generated file.
        .PARAMETER DeleteSet
            String of file names to validate deletion.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > $AzOpsRemovalList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment
            Remove all unique deployments provided from $AzOpsRemovalList
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [bool]
        $CustomTemplateResourceDeletion = (Get-PSFConfigValue -FullName 'AzOps.Core.CustomTemplateResourceDeletion'),

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $DeploymentName = "azops-template-deployment",

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateFilePath = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate'),

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateParameterFilePath,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [object[]]
        $DeletionSupportedResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.DeletionSupportedResourceType'),

        [string[]]
        $DeleteSet
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
                                    Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceDependencyNested' -LogStringValues $roleAssignmentId, $policyAssignment.ResourceId
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
        if ($TemplateParameterFilePath -and $TemplateFilePath -eq (Resolve-Path (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate')).Path) {
            $TemplateFilePath = $TemplateParameterFilePath
        }
        #Deployment Name
        $fileItem = Get-Item -Path $TemplateFilePath
        $removeJobName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
        $removeJobName = "AzOps-RemoveResource-$removeJobName"
        Write-AzOpsMessage -LogLevel Important -LogString 'Remove-AzOpsDeployment.Processing' -LogStringValues $removeJobName, $TemplateFilePath

        #region Parse Content
        $templateContent = Get-Content $TemplateFilePath | ConvertFrom-Json -AsHashtable
        #endregion Parse Content

        #region Validate template type AzOps generated or not
        $schemavalue = '$schema'
        $customDeletion = $false
        if ($templateContent.metadata._generator.name -eq "AzOps" -or $templateContent.$schemavalue -like "*deploymentParameters.json#") {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Remove-AzOpsDeployment.Metadata.AzOps' -LogStringValues $TemplateFilePath
        }
        elseif ($CustomTemplateResourceDeletion -eq $true) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Remove-AzOpsDeployment.Metadata.Custom' -LogStringValues $TemplateFilePath
            $customDeletion = $true
        }
        else {
            Write-AzOpsMessage -LogLevel Error -LogString 'Remove-AzOpsDeployment.Metadata.Failed' -LogStringValues $TemplateFilePath
            return
        }
        #endregion Validate template type AzOps generated or not

        #region Resolve Scope
        try {
            $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.Scope.Failed' -LogStringValues $TemplateFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.Scope.Empty' -LogStringValues $TemplateFilePath
            return
        }
        #endregion Resolve Scope

        #region SetContext
        Set-AzOpsContext -ScopeObject $scopeObject
        #endregion SetContext

        #region remove resources
        if ($customDeletion -eq $false -and $scopeObject.Resource -in $DeletionSupportedResourceType) {
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
                Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $scopeObject.Resource, $scopeObject.Scope
                $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $scopeObject.scope, [environment]::NewLine
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            if ($dependency) {
                foreach ($resource in $dependency) {
                    if ($resource.ResourceId -notin $deletionList.ScopeObject.Scope) {
                        Write-AzOpsMessage -LogLevel Critical -LogString 'Remove-AzOpsDeployment.ResourceDependencyNotFound' -LogStringValues $resource.ResourceId, $scopeObject.Scope
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
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsWhatIfOutput.WhatIfFile'
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            if ($dependencyMissing) {
                return $dependencyMissing
            }
            elseif ($dependency) {
                $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $scopeObject.scope, [environment]::NewLine
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsWhatIfOutput.WhatIfFile'
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            if ($PSCmdlet.ShouldProcess("Remove $($scopeObject.Scope)?")) {
                $null = Remove-AzResource -ResourceId $scopeObject.Scope -Force
            }
            else {
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        elseif ($customDeletion -eq $false -and $scopeObject.Resource -notin $DeletionSupportedResourceType) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.SkipUnsupportedResource' -LogStringValues $TemplateFilePath -Target $scopeObject
            return
        }
        elseif ($customDeletion -eq $true)  {
            # Perform a New-AzOpsDeployment using WhatIf with ResourceIdOnly to extrapolate resources inside template
            $removalJob = New-AzOpsDeployment -DeploymentName $DeploymentName -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath -WhatIfResultFormat 'ResourceIdOnly' -WhatIf:$true
            if ($removalJob.results.Changes.Count -gt 0) {
                # Initialize array to store items that need retry
                $retry = @()
                $removalJobChanges = Set-AzOpsRemoveOrder -DeletionList $removalJob.results.Changes -Index { (New-AzOpsScope -Scope $_.FullyQualifiedResourceId -WhatIf:$false).Resource }
                $allResults = @()
                foreach ($change in $removalJobChanges) {
                    $resource = $null
                    # Check if the resource exists
                    if ($change.RelativeResourceId.StartsWith('Microsoft.Authorization/locks/')) {
                        $resource = Get-AzResourceLock | Where-Object { $_.ResourceId -eq $change.FullyQualifiedResourceId } -ErrorAction SilentlyContinue
                    }
                    else {
                        $resource = Get-AzResource -ResourceId $change.FullyQualifiedResourceId -ErrorAction SilentlyContinue
                    }
                    if ($resource) {
                        $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $change.FullyQualifiedResourceId, [environment]::NewLine
                        $allResults += $results
                        Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsWhatIfOutput.WhatIfFile'
                        # Check if the removal should be performed
                        if ($PSCmdlet.ShouldProcess("Remove $($change.FullyQualifiedResourceId)?")) {
                            $removeAction = Remove-AzResourceRaw -FullyQualifiedResourceId $change.FullyQualifiedResourceId -ScopeObject $ScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
                            # If removal failed, add to retry
                            if ($removeAction.Status -eq 'failed') {
                                $retry += $removeAction
                            }
                        }
                        else {
                            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsDeployment.SkipDueToWhatIf'
                        }
                    }
                    else {
                        # Log warning if resource not found
                        Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $scopeObject.resource, $change.FullyQualifiedResourceId
                        $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $change.FullyQualifiedResourceId, [environment]::NewLine
                        $allResults += $results
                    }

                }
                $baseTemplateCheck = $TemplateFilePath -replace '\.bicep$', '.json'
                if ($TemplateParameterFilePath) {
                    $baseParameterCheck = $TemplateParameterFilePath -replace '\.bicepparam$', 'parameters.json'
                }
                if ($DeleteSet) {
                    $deleteSetCheck = $DeleteSet  -replace '\.bicep$', '.json'
                    $deleteSetCheck = $deleteSetCheck  -replace '\.bicepparam$', '.parameters.json'
                    $resultsFileAssociation = switch ($null) {
                        { $baseTemplateCheck -notin $deleteSetCheck } {
                            'Missing template file association:{1}{0} for deletion.{1}{1}Ensure that you have reviewed and confirmed the necessity of each deletion.{1}If you are deleting files with the extensions .bicep or .bicepparam, keep in mind that AzOps converts them to .json and .parameters.json for deletion processing and outputs the results from the converted files here.{1}' -f $TemplateFilePath, [environment]::NewLine
                        }
                        { $baseParameterCheck -notin $deleteSetCheck } {
                            'Missing parameter file association:{1}{0} for deletion.{1}{1}Ensure that you have reviewed and confirmed the necessity of each deletion.{1}If you are deleting files with the extensions .bicep or .bicepparam, keep in mind that AzOps converts them to .json and .parameters.json for deletion processing and outputs the results from the converted files here.{1}' -f $TemplateParameterFilePath, [environment]::NewLine
                        }
                    }
                    if ($resultsFileAssociation) {
                        $finallResults = @()
                        $finallResults += $resultsFileAssociation
                        $finallResults += $allResults
                        $allResults = $finallResults
                        Write-AzOpsMessage -LogLevel Warning -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $allResults
                    }
                }
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -ParameterFilePath $TemplateParameterFilePath -Results $allResults -RemoveAzOpsFlag $true
                if ($retry.Count -gt 0) {
                    # Retry failed removals recursively
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsDeployment.Resource.RetryCount' -LogStringValues $retry.Count
                    foreach ($try in $retry) { $try.Status = $null }
                    $removeActionRecursive = Remove-AzResourceRawRecursive -InputObject $retry
                    $removeActionRecursiveRemaining = $removeActionRecursive | Where-Object { $_.Status -eq 'failed' }
                    return $removeActionRecursiveRemaining
                }
            }
            else {
                # No resource to remove was found
                Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $scopeObject.Resource, $scopeObject.Scope
                $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $scopeObject.scope, [environment]::NewLine
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -ParameterFilePath $TemplateParameterFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
        }
        #endregion remove resources
    }
}