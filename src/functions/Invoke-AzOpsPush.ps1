function Invoke-AzOpsPush {

    <#
        .SYNOPSIS
            Applies a change to Azure from the AzOps configuration.
        .DESCRIPTION
            Applies a change to Azure from the AzOps configuration.
        .PARAMETER ChangeSet
            Set of changes from the last execution that need to be applied.
        .PARAMETER DeleteSetContents
            Set of content from the deleted files in ChangeSet.
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .PARAMETER AzOpsMainTemplate
            Path to the main template used by AzOps
        .PARAMETER CustomSortOrder
            Switch to honor the input ordering for ChangeSet. If not used, ChangeSet will be sorted in ascending order.
        .EXAMPLE
            > Invoke-AzOpsPush -ChangeSet changeSet -StatePath $StatePath -AzOpsMainTemplate $templatePath
            Applies a change to Azure from the AzOps configuration.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [Alias("Invoke-AzOpsChange")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $ChangeSet,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string[]]
        $DeleteSetContents,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [string]
        $AzOpsMainTemplate = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate'),

        [switch]
        $CustomSortOrder
    )

    begin {
        #region Utility Functions
        function Resolve-ArmFileAssociation {
            [CmdletBinding()]
            param (
                [AzOpsScope]
                $ScopeObject,

                [string]
                $FilePath,

                [string]
                $AzOpsMainTemplate
            )

            #region Initialization Prep
            $common = @{
                Level        = 'Host'
                Tag          = 'pwsh'
                FunctionName = 'Invoke-AzOpsPush'
                Target       = $ScopeObject
            }

            $result = [PSCustomObject] @{
                TemplateFilePath          = $null
                TemplateParameterFilePath = $null
                DeploymentName            = $null
                ScopeObject               = $ScopeObject
                Scope                     = $ScopeObject.Scope
            }

            $fileItem = Get-Item -Path $FilePath
            if ($fileItem.Extension -notin '.json' , '.bicep', '.bicepparam') {
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsPush.Resolve.NoJson' -StringValues $fileItem.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsPush' -Target $ScopeObject
                return
            }

            # Generate deterministic id for DefaultDeploymentRegion to overcome deployment issues when changing DefaultDeploymentRegion
            $deploymentRegionId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)
            #endregion Initialization Prep

            #region Case: Parameters File
            if (($fileItem.Name.EndsWith('.parameters.json')) -or ($fileItem.Name.EndsWith('.bicepparam'))) {
                $result.TemplateParameterFilePath = $fileItem.FullName
                $deploymentName = $fileItem.Name -replace (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'), '' -replace ' ', '_' -replace '\.bicepparam', ''
                if ($deploymentName.Length -gt 53) { $deploymentName = $deploymentName.SubString(0, 53) }
                $result.DeploymentName = 'AzOps-{0}-{1}' -f $deploymentName, $deploymentRegionId

                #region Directly Associated Template file exists
                switch ($fileItem.Name) {
                    { $_.EndsWith('.parameters.json') } {
                        if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $fileItem.FullName.Split('.')[-3] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -StringValues $FilePath
                            $templatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-3])"), '' -replace '\.parameters.json', '.json'
                            $bicepTemplatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-3])"), '' -replace '.parameters.json', '.bicep'
                        }
                        else {
                            $templatePath = $fileItem.FullName -replace '\.parameters.json', (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')
                            $bicepTemplatePath = $fileItem.FullName -replace '.parameters.json', '.bicep'
                        }
                        if (Test-Path $templatePath) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FoundTemplate' -StringValues $FilePath, $templatePath
                            $result.TemplateFilePath = $templatePath
                            return $result
                        }
                        elseif (Test-Path $bicepTemplatePath) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -StringValues $FilePath, $bicepTemplatePath
                            $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $bicepTemplatePath -SkipParam
                            $result.TemplateFilePath = $transpiledTemplatePaths.transpiledTemplatePath
                            return $result
                        }
                    }
                    { $_.EndsWith('.bicepparam') } {
                        if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $fileItem.FullName.Split('.')[-2] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -StringValues $FilePath
                            $bicepTemplatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-2])"), '' -replace '\.bicepparam', '.bicep'
                        }
                        else {
                            $bicepTemplatePath = $fileItem.FullName -replace '\.bicepparam', '.bicep'
                        }
                        if (Test-Path $bicepTemplatePath) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -StringValues $FilePath, $bicepTemplatePath
                            $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $bicepTemplatePath -BicepParamTemplatePath $fileItem.FullName
                            $result.TemplateFilePath = $transpiledTemplatePaths.transpiledTemplatePath
                            $result.TemplateParameterFilePath = $transpiledTemplatePaths.transpiledParametersPath
                            return $result
                        }
                    }
                }
                #endregion Directly Associated Template file exists

                #region Check in the main template file for a match
                Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Resolve.NotFoundTemplate' -StringValues $FilePath, $templatePath
                $mainTemplateItem = Get-Item $AzOpsMainTemplate
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FromMainTemplate' -StringValues $mainTemplateItem.FullName

                # Determine Resource Type in Parameter file
                $templateParameterFileHashtable = Get-Content -Path $fileItem.FullName | ConvertFrom-Json -AsHashtable
                $effectiveResourceType = $null
                if ($templateParameterFileHashtable.Keys -contains "`$schema") {
                    if ($templateParameterFileHashtable.parameters.input.value.Keys -ccontains "Type") {
                        # ManagementGroup and Subscription
                        $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.Type
                    }
                    elseif ($templateParameterFileHashtable.parameters.input.value.Keys -ccontains "type") {
                        # ManagementGroup and Subscription
                        $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.type
                    }
                    elseif ($templateParameterFileHashtable.parameters.input.value.Keys -contains "ResourceType") {
                        # Resource
                        $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.ResourceType
                    }
                }
                # Check if generic template is supporting the resource type for the deployment.
                if ($effectiveResourceType -and
                    (Get-Content $mainTemplateItem.FullName | ConvertFrom-Json -AsHashtable).variables.apiVersionLookup.Keys -contains $effectiveResourceType) {
                    Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.MainTemplate.Supported' -StringValues $effectiveResourceType, $mainTemplateItem.FullName
                    $result.TemplateFilePath = $mainTemplateItem.FullName
                    return $result
                }
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsPush.Resolve.MainTemplate.NotSupported' -StringValues $effectiveResourceType, $mainTemplateItem.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsPush' -Target $ScopeObject
                return
                #endregion Check in the main template file for a match
                # All Code paths end the command
            }
            #endregion Case: Parameters File

            #region Case: Template File
            $result.TemplateFilePath = $fileItem.FullName
            $parameterPath = Join-Path $fileItem.Directory.FullName -ChildPath ($fileItem.BaseName + '.parameters' + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
            if (Test-Path -Path $parameterPath) {
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.ParameterFound' -StringValues $FilePath, $parameterPath
                $result.TemplateParameterFilePath = $parameterPath
            }
            elseif ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and (Get-PSFConfigValue -FullName 'AzOps.Core.DeployAllMultipleTemplateParameterFiles') -eq $true) {
                # Check for multiple associated template parameter files
                $paramFileList = Get-ChildItem -Path $fileItem.Directory | Where-Object { ($_.Name.Split('.')[-3] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) -or ($_.Name.Split('.')[-2] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) }
                if ($paramFileList) {
                    $multiResult = @()
                    foreach ($paramFile in $paramFileList) {
                        # Process possible parameter files for template equivalent
                        if (($fileItem.FullName.Split('.')[-2] -eq $paramFile.FullName.Split('.')[-3]) -or ($fileItem.FullName.Split('.')[-2] -eq $paramFile.FullName.Split('.')[-4])) {
                            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -StringValues $paramFile.FullName
                            $multiResult += Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $paramFile -AzOpsMainTemplate $AzOpsMainTemplate
                        }
                    }
                    if ($multiResult) {
                        # Return completed object
                        return $multiResult
                    }
                    else {
                        Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -StringValues $FilePath, $parameterPath
                    }

                }
            }
            else {
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -StringValues $FilePath, $parameterPath
                if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true) {
                    # Check for template parameters without defaultValue
                    $defaultValueContent = Get-Content $FilePath
                    $missingDefaultParam = $defaultValueContent | jq '.parameters | with_entries(select(.value.defaultValue == null))' | ConvertFrom-Json -AsHashtable
                    if ($missingDefaultParam.Count -ge 1) {
                        # Skip template deployment when template parameters without defaultValue are found and no parameter file identified
                        $missingString = foreach ($item in $missingDefaultParam.Keys.GetEnumerator()) {"$item,"}
                        Write-PSFMessage -Level Verbose -String 'Invoke-AzOpsPush.Resolve.NotFoundParamFileDefaultValue' -StringValues $FilePath, ($missingString | Out-String -NoNewline)
                        continue
                    }
                }
            }

            $deploymentName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
            if ($deploymentName.Length -gt 53) { $deploymentName = $deploymentName.SubString(0, 53) }
            $result.DeploymentName = 'AzOps-{0}-{1}' -f $deploymentName, $deploymentRegionId

            $result
            #endregion Case: Template File
        }
        #endregion Utility Functions

        $common = @{
            Level = 'Host'
            Tag   = 'git'
        }

        $WhatIfPreferenceState = $WhatIfPreference
        $WhatIfPreference = $false

        # Remove lingering files from previous run
        $tempPath = [System.IO.Path]::GetTempPath()
        if ((Test-Path -Path ($tempPath + 'OUTPUT.md')) -or (Test-Path -Path ($tempPath + 'OUTPUT.json'))) {
            Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile.Remove'
            Remove-Item -Path ($tempPath + 'OUTPUT.md') -Force -ErrorAction SilentlyContinue
            Remove-Item -Path ($tempPath + 'OUTPUT.json') -Force -ErrorAction SilentlyContinue
        }
    }

    process {
        if (-not $ChangeSet) { return }
        Assert-AzOpsInitialization -Cmdlet $PSCmdlet -StatePath $StatePath
        #Supported resource types for deletion
        $DeletionSupportedResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.DeletionSupportedResourceType')
        #region Categorize Input
        Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Deployment.Required'
        $deleteSet = @()
        $addModifySet = foreach ($change in $ChangeSet) {
            $operation, $filename = ($change -split "`t")[0, -1]
            if ($operation -eq 'D') {
                $deleteSet += $filename
                continue
            }
            if ($operation -in 'A', 'M') { $filename }
            elseif ($operation -match '^R[0-9][0-9][0-9]$') {
                $operation, $oldFileLocation, $newFileLocation = ($change -split "`t")[0, 1, 2]
                if (-not ((Split-Path -Path $oldFileLocation) -eq (Split-Path -Path $newFileLocation))) {
                    $deleteSet += $oldFileLocation
                }
                $newFileLocation
            }
        }
        if ($deleteSet -and -not $CustomSortOrder) { $deleteSet = $deleteSet | Sort-Object }
        if ($addModifySet -and -not $CustomSortOrder) { $addModifySet = $addModifySet | Sort-Object }

        if ($addModifySet) {
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.AddModify'
            foreach ($item in $addModifySet) {
                Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.AddModify.File' -StringValues $item
            }
        }
        if ($DeleteSetContents -and $deleteSet) {
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.Delete'
            # Unique delimiter used to join, split and replace data in DeleteSetContents
            $delimiter = (New-Guid).Guid
            # Transform $DeleteSetContents for further processing
            $DeleteSetContents = $DeleteSetContents -join $delimiter -split "$delimiter-- " -replace $delimiter,""
            # Process each $deleteSet $item
            foreach ($item in $deleteSet) {
                Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.Delete.File' -StringValues $item
                # Processing each $deleteSet, compare it to each $DeleteSetContents
                foreach ($content in $DeleteSetContents) {
                    if ($content.Contains($item)) {
                        # Transform original first line in content with missing delimiter
                        if ($content.StartsWith("-- ")) {
                            $jsonValue = $content.replace("-- $item", "")
                        }
                        # Transform remaining content
                        else {
                            $jsonValue = $content.replace($item, "")
                        }
                        # When processed as designed there is no file present in the running branch. To run a removal AzOps re-creates the file and content based on $DeleteSetContents momentarily for processing, it is disregarded afterwards.
                        if (-not(Test-Path -Path (Split-Path -Path $item))) {
                            New-Item -Path (Split-Path -Path $item) -ItemType Directory | Out-Null
                        }
                        # Update item
                        Set-Content -Path $item -Value $jsonValue
                    }
                }
            }
        }
        #endregion Categorize Input

        #region Deploy State
        $common.Tag = 'pwsh'
        # Nested Pipeline allows economizing on New-AzOpsStateDeployment having to run its "begin" block once only
        $newStateDeploymentCmd = { New-AzOpsStateDeployment -StatePath $StatePath }.GetSteppablePipeline()
        $newStateDeploymentCmd.Begin($true)
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.subscription.json$') { continue }
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Deploy.Subscription' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.providerfeatures.json$') { continue }
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Deploy.ProviderFeature' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.resourceproviders.json$') { continue }
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Deploy.ResourceProvider' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        $newStateDeploymentCmd.End()
        #endregion Deploy State

        $deploymentList = foreach ($addition in $addModifySet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {

            # Avoid duplicate entries in the deployment list
            if ($addition.EndsWith(".parameters.json")) {
                if ($addModifySet -contains $addition.Replace(".parameters.json", ".json") -or $addModifySet -contains $addition.Replace(".parameters.json", ".bicep")) {
                    continue
                }
            }
            if ($addition.EndsWith(".bicepparam")) {
                if ($addModifySet -contains $addition.Replace(".bicepparam", ".bicep")) {
                    continue
                }
            }

            # Handle Bicep templates
            if ($addition.EndsWith(".bicep")) {
                $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $addition | Select-Object transpiledTemplatePath
                $addition = $transpiledTemplatePaths.transpiledTemplatePath
            }

            try {
                $scopeObject = New-AzOpsScope -Path $addition -StatePath $StatePath -ErrorAction Stop
            }
            catch {
                Write-PSFMessage -Level Debug @common -String 'Invoke-AzOpsPush.Scope.Failed' -StringValues $addition, $StatePath -Target $addition -ErrorRecord $_
                continue
            }

            Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $addition -AzOpsMainTemplate $AzOpsMainTemplate
        }

        $deletionList = foreach ($deletion in $deleteSet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {

            if ($deletion.EndsWith(".bicep")) {
                continue
            }

            $templateContent = Get-Content $deletion | ConvertFrom-Json -AsHashtable
            $schemavalue = '$schema'
            if ($templateContent.$schemavalue -like "*deploymentParameters.json#" -and (-not($templateContent.parameters.input.value.type -in $DeletionSupportedResourceType))) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.SkipUnsupportedResource' -StringValues $deletion -Target $scopeObject
                continue
            }
            elseif ($templateContent.$schemavalue -like "*deploymentTemplate.json#" -and (-not($templateContent.resources[0].type -in $DeletionSupportedResourceType))) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.SkipUnsupportedResource' -StringValues $deletion -Target $scopeObject
                continue
            }

            try {
                $scopeObject = New-AzOpsScope -Path $deletion -StatePath $StatePath -ErrorAction Stop
            }
            catch {
                Write-PSFMessage -Level Debug @common -String 'Invoke-AzOpsPush.Scope.Failed' -StringValues $deletion, $StatePath -Target $deletion -ErrorRecord $_
                continue
            }

            Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $deletion -AzOpsMainTemplate $AzOpsMainTemplate
        }

        #Required deletion order
        $deletionListPriority = @(
            "locks",
            "policyExemptions",
            "policyAssignments",
            "policySetDefinitions",
            "policyDefinitions"
        )

        #Sort 'deletionList' based on 'deletionListPriority'
        $deletionList = $deletionList | Sort-Object -Property {$deletionListPriority.IndexOf($_.ScopeObject.Resource)}

        #If addModifySet exists and no deploymentList has been generated at the same time as the StatePath root has additional directories and AllowMultipleTemplateParameterFiles is default false, exit with terminating error
        if (($addModifySet -and -not $deploymentList) -and (Get-ChildItem -Path $StatePath -Directory) -and ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $false)) {
            Write-PSFMessage -Level Critical @common -String 'Invoke-AzOpsPush.DeploymentList.NotFound'
            throw
        }

        #Starting deployment
        $WhatIfPreference = $WhatIfPreferenceState
        $uniqueProperties = 'Scope', 'DeploymentName', 'TemplateFilePath', 'TemplateParameterFilePath'
        $uniqueDeployment = $deploymentList | Select-Object $uniqueProperties -Unique
        $deploymentResult = @()

        #Determine what deployment pattern to adopt serial or parallel
        if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and (Get-PSFConfigValue -FullName 'AzOps.Core.ParallelDeploymentMultipleTemplateParameterFiles') -eq $true) {
            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.ParallelCondition'
            # Group deployments based on TemplateFilePath
            $groups = $uniqueDeployment | Group-Object -Property TemplateFilePath | Where-Object { $_.Count -ge '2' -and $_.Name -ne $(Get-Item $AzOpsMainTemplate).FullName }
            if ($groups) {
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.ParallelGroup'
                $processedTargets = @()
                # Process each deployment and evaluate serial or parallel deployment pattern
                foreach ($deployment in $uniqueDeployment) {
                    if ($deployment.TemplateFilePath -in $groups.Name -and $deployment -notin $processedTargets) {
                        # Deployment part of group association for parallel processing, process entire group as parallel deployment
                        $targets = $($groups | Where-Object { $_.Name -eq $deployment.TemplateFilePath }).Group
                        Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.Parallel' -StringValues $deployment.TemplateFilePath, $targets.Count
                        # Prepare Input Data for parallel processing
                        $runspaceData = @{
                            AzOpsPath                       = "$($script:ModuleRoot)\AzOps.psd1"
                            StatePath                       = $StatePath
                            WhatIfPreference                = $WhatIfPreference
                            runspace_AzOpsAzManagementGroup = $script:AzOpsAzManagementGroup
                            runspace_AzOpsSubscriptions     = $script:AzOpsSubscriptions
                            runspace_AzOpsPartialRoot       = $script:AzOpsPartialRoot
                            runspace_AzOpsResourceProvider  = $script:AzOpsResourceProvider
                        }
                        # Pass deployment targets for parallel processing and output deployment result for later
                        $deploymentResult += $targets | Foreach-Object -ThrottleLimit (Get-PSFConfigValue -FullName 'AzOps.Core.ThrottleLimit') -Parallel {
                            $deployment = $_
                            $runspaceData = $using:runspaceData

                            Import-Module "$([PSFramework.PSFCore.PSFCoreHost]::ModuleRoot)/PSFramework.psd1"
                            $azOps = Import-Module $runspaceData.AzOpsPath -Force -PassThru

                            & $azOps {
                                $script:AzOpsAzManagementGroup = $runspaceData.runspace_AzOpsAzManagementGroup
                                $script:AzOpsSubscriptions = $runspaceData.runspace_AzOpsSubscriptions
                                $script:AzOpsPartialRoot = $runspaceData.runspace_AzOpsPartialRoot
                                $script:AzOpsResourceProvider = $runspaceData.runspace_AzOpsResourceProvider
                            }

                            & $azOps {
                                $deployment | New-AzOpsDeployment -WhatIf:$runspaceData.WhatIfPreference
                            }
                        }
                        # Add targets to processed list to avoid duplicate deployment
                        $processedTargets += $targets
                    }
                    elseif ($deployment -notin $processedTargets) {
                        # Deployment not part of group association for parallel processing, process this as serial deployment
                        Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.Serial' -StringValues $deployment.Count
                        $deploymentResult += $deployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
                    }
                    else {
                        # Deployment already processed by group association from parallel processing, skip this duplicate deployment
                        Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.Skip' -StringValues $deployment.TemplateFilePath, $deployment.TemplateParameterFilePath
                    }
                }
            }
            else {
                # No deployments with matching TemplateFilePath identified
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.Serial' -StringValues $deployment.Count
                $deploymentResult += $uniqueDeployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
            }
        } else {
            # Perform serial deployment only
            Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Deployment.Serial' -StringValues $uniqueDeployment.Count
            $deploymentResult += $uniqueDeployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
        }

        if ($deploymentResult) {
            #Process deploymentResult and output result
            foreach ($result in $deploymentResult) {
                Set-AzOpsWhatIfOutput -FilePath $result.filePath -ParameterFilePath $result.parameterFilePath -Results $result.results
            }
        }

        #Removal of Supported resourceTypes
        $uniqueProperties = 'Scope', 'TemplateFilePath', 'TemplateParameterFilePath'
        $removalJob = $deletionList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment -WhatIf:$WhatIfPreference
        if ($removalJob.dependencyMissing -eq $true) {
            Write-PSFMessage -Level Critical @common -String 'Invoke-AzOpsPush.Dependency.Missing'
            throw
        }
    }
}