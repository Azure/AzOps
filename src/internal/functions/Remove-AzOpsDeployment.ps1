﻿function Remove-AzOpsDeployment {

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
        $DeploymentStackTemplateFilePath,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [object]
        $DeploymentStackSettings,

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
            if ($resourceToDelete.Type -in $DeletionSupportedResourceType) {
                $subPattern = '^/subscriptions/([0-9a-fA-F-]{36})'
                $rgPattern = '^/subscriptions/([0-9a-fA-F-]{36})/resourceGroups/([^/]+)'
                if ($resourceToDelete.Id -match $subPattern) {
                    $deletionScope = $matches[0]
                    $depLock = Get-AzResourceLock -Scope $deletionScope
                    if ($depLock) {
                        foreach ($lock in $depLock) {
                            #Filter through each return and validate if resource has rg and is not at child resource scope
                            if ($lock.ResourceId -match $rgPattern) {
                                if ($resourceToDelete.Id.StartsWith($matches[0]) -and $lock.ResourceId -notlike '*/resourcegroups/*/providers/*/providers/*') {
                                    $dependency += [PSCustomObject]@{
                                        Type = 'locks'
                                        Id = $lock.ResourceId
                                    }
                                }
                            }
                            elseif ($lock.ResourceId -notlike '*/resourcegroups/*') {
                                $dependency += [PSCustomObject]@{
                                    Type = 'locks'
                                    Id = $lock.ResourceId
                                }
                            }
                        }
                        if ($dependency) {
                            $dependency = $dependency | Sort-Object Id -Unique | Where-Object {$_.Id -ne $resourceToDelete.Id}
                            return $dependency
                        }
                    }
                }
            }
        }
        function Get-AzPolicyAssignmentDeletionDependency {
            param (
                $resourceToDelete
            )
            $dependency = @()
            if ($resourceToDelete.Type -in $DeletionSupportedResourceType) {
                switch ($resourceToDelete.Type) {
                    'Microsoft.Authorization/policyAssignments' {
                        $depPolicyAssignment = $resourceToDelete
                    }
                    'Microsoft.Authorization/policyDefinitions' {
                        $depPolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $resourceToDelete.Id -ErrorAction SilentlyContinue
                    }
                    'Microsoft.Authorization/policySetDefinitions' {
                        $query = "PolicyResources | where type == 'microsoft.authorization/policyassignments' and properties.policyDefinitionId == '$($resourceToDelete.Id)' | order by id asc"
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
                        Type = $policyAssignment.Type
                        Id = $policyAssignment.Id
                    }
                    if ($policyAssignment.IdentityType -eq 'SystemAssigned') {
                        $depSystemAssignedRoleAssignment = $null
                        $depSystemAssignedRoleAssignment = Get-AzRoleAssignment -ObjectId $policyAssignment.IdentityPrincipalId -Scope $policyAssignment.Scope
                        if ($depSystemAssignedRoleAssignment) {
                            foreach ($roleAssignmentId in $depSystemAssignedRoleAssignment.RoleAssignmentId) {
                                #Filter through each return and validate resource is not at child resource scope
                                if ($roleAssignmentId -notlike '*/resourcegroups/*/providers/*/providers/*') {
                                    $dependency += [PSCustomObject]@{
                                        Type = 'roleAssignments'
                                        Id = $roleAssignmentId
                                    }
                                }
                                else {
                                    Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceDependencyNested' -LogStringValues $roleAssignmentId, $policyAssignment.Id
                                }
                            }
                        }
                    }
                }
            }
            if ($dependency) {
                $dependency = $dependency | Sort-Object Id -Unique | Where-Object {$_.Id -ne $resourceToDelete.Id}
                return $dependency
            }
        }
        function Get-AzPolicyDefinitionDeletionDependency {
            param (
                $resourceToDelete
            )
            if ($resourceToDelete.Type -eq 'Microsoft.Authorization/policyDefinitions') {
                $dependency = @()
                $query = "PolicyResources | where type == 'microsoft.authorization/policysetdefinitions' and properties.policyType == 'Custom' | project id, type, policyDefinitions = (properties.policyDefinitions) | mv-expand policyDefinitions | project id, type, policyDefinitionId = tostring(policyDefinitions.policyDefinitionId) | where policyDefinitionId == '$($resourceToDelete.Id)' | order by policyDefinitionId asc | order by id asc"
                $depPolicySetDefinition = Search-AzGraphDeletionDependency -query $query
                if ($depPolicySetDefinition) {
                    $depPolicySetDefinition = foreach ($policySetDefinition in $depPolicySetDefinition) {
                        #Loop through each return from graph cache and validate resource is still present in Azure
                        $policy = Get-AzPolicySetDefinition -Id $policySetDefinition.Id -ErrorAction SilentlyContinue
                        if ($policy) {
                            $dependency += [PSCustomObject]@{
                                Type = $policy.Type
                                Id = $policy.Id
                            }
                            $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $policy
                        }
                    }
                }
                if ($dependency) {
                    $dependency = $dependency | Sort-Object Id -Unique | Where-Object {$_.Id -ne $resourceToDelete.Id}
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
        if ($null -ne $DeploymentStackSettings) {
            $removeJobName = $DeploymentName
        }
        else {
            $fileItem = Get-Item -Path $TemplateFilePath -Force
            $removeJobName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
            $removeJobName = "AzOps-RemoveResource-$removeJobName"
        }
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
        elseif ($true -eq $CustomTemplateResourceDeletion) {
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
                    $resourceToDelete = Get-AzResourceLock -Scope "/subscriptions/$($ScopeObject.Subscription)" -ErrorAction SilentlyContinue | Where-Object { $_.ResourceID -eq $ScopeObject.Scope }
                }
                'policyAssignments' {
                    $resourceToDelete = Get-AzPolicyAssignment -Id $scopeObject.Scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policyDefinitions' {
                    $resourceToDelete = Get-AzPolicyDefinition -Id $scopeObject.Scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzPolicyDefinitionDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policyExemptions' {
                    $resourceToDelete = Get-AzPolicyExemption -Id $scopeObject.Scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'policySetDefinitions' {
                    $resourceToDelete = Get-AzPolicySetDefinition -Id $scopeObject.Scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $dependency += Get-AzPolicyAssignmentDeletionDependency -resourceToDelete $resourceToDelete
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
                'roleAssignments' {
                    $response = Invoke-AzRestMethod -Path "$($scopeObject.Scope)?api-version=2022-04-01" -ErrorAction SilentlyContinue
                    if ($response.StatusCode -eq 200) {
                        $resourceToDelete = $response.Content | ConvertFrom-Json -Depth 100
                        if ($resourceToDelete) {
                            $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                        }
                    }
                }
                'resourceGroups' {
                    $resourceToDelete = Get-AzResourceGroup -Id $scopeObject.Scope -ErrorAction SilentlyContinue
                    if ($resourceToDelete) {
                        $resourceToDelete | Add-Member -MemberType NoteProperty -Name "Type" -Value "$($scopeObject.Type)"
                        $resourceToDelete | Add-Member -MemberType NoteProperty -Name "SubscriptionId" -Value "$($scopeObject.Subscription)"
                        $resourceToDelete | Add-Member -MemberType NoteProperty -Name "Id" -Value "$($resourceToDelete.ResourceId)"
                        $dependency += Get-AzLocksDeletionDependency -resourceToDelete $resourceToDelete
                    }
                }
            }
            # If no resource to delete was found return
            if (-not $resourceToDelete) {
                Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $scopeObject.Resource, $scopeObject.Scope
                $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $scopeObject.scope, [environment]::NewLine
                if ($WhatIfPreference) {
                    Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $results -RemoveAzOpsFlag $true
                }
                return
            }
            if ($dependency) {
                foreach ($resource in $dependency) {
                    if ($resource.Id -notin $deletionList.ScopeObject.Scope) {
                        Write-AzOpsMessage -LogLevel Critical -LogString 'Remove-AzOpsDeployment.ResourceDependencyNotFound' -LogStringValues $resource.Id, $scopeObject.Scope
                        $results = 'Missing resource dependency:{2}{0} for successful deletion of {1}.{2}{2}Please add dependent resource to pull request and retry.' -f $resource.Id, $scopeObject.scope, [environment]::NewLine
                        $dependencyMissing = [PSCustomObject]@{
                            dependencyMissing = $true
                        }
                        if ($WhatIfPreference) {
                            Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $results -RemoveAzOpsFlag $true
                        }
                    }
                }
            }
            else {
                $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $scopeObject.scope, [environment]::NewLine
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                if ($WhatIfPreference) {
                    Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $results -RemoveAzOpsFlag $true
                }
            }
            if ($dependencyMissing) {
                return $dependencyMissing
            }
            elseif ($dependency) {
                $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $scopeObject.scope, [environment]::NewLine
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                if ($WhatIfPreference) {
                    Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $results -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -RemoveAzOpsFlag $true
                }
            }
            if ($PSCmdlet.ShouldProcess("Remove $($scopeObject.Scope)?")) {
                $null = Remove-AzResourceRaw -ScopeObject $scopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
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
            $allResults = @()
            $retry = @()
            # Check if DeploymentStackSettings exists
            if ($null -ne $DeploymentStackSettings) {
                # Check if the resource exists
                $resource = Get-AzOpsResource -DeploymentStackName $removeJobName -ScopeObject $scopeObject -ErrorAction SilentlyContinue
                if ($resource) {
                    $deploymentStackScopeObject = New-AzOpsScope -Scope $resource.Id -WhatIf:$false
                    $results = 'What if successful:{1}Performing the operation:{1}Deletion of Deployment Stack: {0}{1}Actions: resourcesCleanupAction: {2}, resourceGroupsCleanupAction: {3}, managementGroupsCleanupAction: {4}{1}Associated resources: {1}{5}' -f $deploymentStackScopeObject.Scope, [environment]::NewLine, $resource.resourcesCleanupAction, $resource.resourceGroupsCleanupAction, $resource.managementGroupsCleanupAction, ($resource.Resources.Id | Out-String)
                    $allResults += $results
                    Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                    # Check if the removal should be performed
                    if ($PSCmdlet.ShouldProcess("Remove $($deploymentStackScopeObject.Scope)?")) {
                        $removeAction = Remove-AzResourceRaw -ScopeObject $deploymentStackScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
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
                    Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $ScopeObject.Resource, $removeJobName
                    $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $change.FullyQualifiedResourceId, [environment]::NewLine
                    return
                }
            }
            else {
                # Perform a New-AzOpsDeployment using WhatIf with ResourceIdOnly to extrapolate resources inside template
                $removalJob = New-AzOpsDeployment -DeploymentName $DeploymentName -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath -WhatIfResultFormat 'ResourceIdOnly' -WhatIf:$true
                if ($removalJob.results.Changes.Count -gt 0) {
                    # Initialize array to store items that need retry
                    $removalJobChanges = Set-AzOpsRemoveOrder -DeletionList $removalJob.results.Changes -Index { (New-AzOpsScope -Scope $_.FullyQualifiedResourceId -WhatIf:$false).Resource }
                    foreach ($change in $removalJobChanges) {
                        $resource = $null
                        $resourceScopeObject = $null
                        $removeAction = $null
                        # Check if the resource exists
                        $resourceScopeObject = New-AzOpsScope -Scope $change.FullyQualifiedResourceId -WhatIf:$false
                        $resource = Get-AzOpsResource -ScopeObject $resourceScopeObject -ErrorAction SilentlyContinue
                        if ($resource) {
                            $results = 'What if successful:{1}Performing the operation:{1}Deletion of target resource {0}.' -f $resourceScopeObject.Scope, [environment]::NewLine
                            $allResults += $results
                            Write-AzOpsMessage -LogLevel Verbose -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $results
                            # Check if the removal should be performed
                            if ($PSCmdlet.ShouldProcess("Remove $($resourceScopeObject.Scope)?")) {
                                $removeAction = Remove-AzResourceRaw -ScopeObject $resourceScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
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
                            Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $ScopeObject.Resource, $change.FullyQualifiedResourceId
                            $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $change.FullyQualifiedResourceId, [environment]::NewLine
                            $allResults += $results
                        }
                    }
                }
                else {
                    # No resource to remove was found
                    Write-AzOpsMessage -LogLevel Warning -LogString 'Remove-AzOpsDeployment.ResourceNotFound' -LogStringValues $scopeObject.Resource, $scopeObject.Scope
                    $results = 'What if operation failed:{1}Deletion of target resource {0}.{1}Resource could not be found' -f $scopeObject.Scope, [environment]::NewLine
                    if ($WhatIfPreference) {
                        Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -ParameterFilePath $TemplateParameterFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $results -RemoveAzOpsFlag $true
                    }
                    return
                }
            }
            $baseTemplateCheck = $TemplateFilePath -replace '\.bicep$', '.json'
            if ($TemplateParameterFilePath) {
                $baseParameterCheck = $TemplateParameterFilePath -replace '\.bicepparam$', 'parameters.json'
            }
            if ($DeleteSet) {
                $deleteSetCheck = $DeleteSet  -replace '\.bicep$', '.json'
                $deleteSetCheck = $deleteSetCheck  -replace '\.bicepparam$', '.parameters.json'
                # Check if template and parameter file exist in $DeleteSet, example AzOps has been instructed to remove template.json but not the associated parameter.json
                $resultsFileAssociation = switch ($null) {
                    { $baseTemplateCheck -notin $deleteSetCheck -and $baseParameterCheck -notin $deleteSetCheck } {
                        'Missing template and parameter file association:{2}{0} and {1} for deletion.{2}{2}Ensure that you have reviewed and confirmed the necessity of each deletion.{2}If you are deleting files with extension .bicep or .bicepparam, keep in mind that AzOps converts them to .json or .parameters.json for deletion processing and outputs the results from the converted files here.{2}' -f $TemplateFilePath, $TemplateParameterFilePath, [environment]::NewLine
                    }
                    { $baseTemplateCheck -notin $deleteSetCheck } {
                        'Missing template file association:{1}{0} for deletion.{1}{1}Ensure that you have reviewed and confirmed the necessity of each deletion.{1}If you are deleting files with extension .bicep or .bicepparam, keep in mind that AzOps converts them to .json or .parameters.json for deletion processing and outputs the results from the converted files here.{1}' -f $TemplateFilePath, [environment]::NewLine
                    }
                    { $baseParameterCheck -notin $deleteSetCheck } {
                        'Missing parameter file association:{1}{0} for deletion.{1}{1}Ensure that you have reviewed and confirmed the necessity of each deletion.{1}If you are deleting files with extension .bicep or .bicepparam, keep in mind that AzOps converts them to .json or .parameters.json for deletion processing and outputs the results from the converted files here.{1}' -f $TemplateParameterFilePath, [environment]::NewLine
                    }
                }
                # If there are $resultsFileAssociation, combine them with existing results and log a warning
                if ($resultsFileAssociation) {
                    $finalResults = @()
                    $finalResults += $resultsFileAssociation
                    $finalResults += $allResults
                    $allResults = $finalResults
                    Write-AzOpsMessage -LogLevel Warning -LogString 'Set-AzOpsWhatIfOutput.WhatIfResults' -LogStringValues $allResults
                }
            }
            if ($WhatIfPreference) {
                Set-AzOpsWhatIfOutput -FilePath $TemplateFilePath -ParameterFilePath $TemplateParameterFilePath -DeploymentStackTemplateFilePath $DeploymentStackTemplateFilePath -Results $allResults -RemoveAzOpsFlag $true
            }
            if ($retry.Count -gt 0) {
                # Retry failed removals recursively
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsDeployment.Resource.RetryCount' -LogStringValues $retry.Count
                foreach ($try in $retry) { $try.Status = $null }
                $removeActionRecursive = Remove-AzResourceRaw -InputObject $retry -Recursive
                $removeActionRecursiveRemaining = $removeActionRecursive | Where-Object { $_.Status -eq 'failed' }
                return $removeActionRecursiveRemaining
            }
        }
        #endregion remove resources
    }
}