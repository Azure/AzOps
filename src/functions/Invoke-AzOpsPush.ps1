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
        function New-AzOpsList {
            [CmdletBinding()]
            param (
                [string[]]
                $FileSet,
                [string]
                $FilePath,
                [string]
                $AzOpsMainTemplate,
                [string[]]
                $ConvertedTemplate,
                [string[]]
                $ConvertedParameter
            )

            # Avoid duplicate entries in the deployment list
            if ($FilePath.EndsWith(".parameters.json")) {
                if ($FileSet -contains $FilePath.Replace(".parameters.json", ".json") -or $FileSet -contains $FilePath.Replace(".parameters.json", ".bicep")) {
                    continue
                }
            }
            if ($FilePath.EndsWith(".bicepparam")) {
                if ($FileSet -contains $FilePath.Replace(".bicepparam", ".bicep")) {
                    continue
                }
            }

            # Handle Bicep templates
            if ($FilePath.EndsWith(".bicep")) {
                $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $FilePath -ConvertedTemplate $ConvertedTemplate -ConvertedParameter $ConvertedParameter
                if ($true -eq $transpiledTemplatePaths.transpiledTemplateNew) {
                    $ConvertedTemplate += $transpiledTemplatePaths.transpiledTemplatePath
                }
                if ($true -eq $transpiledTemplatePaths.transpiledParametersNew) {
                    $ConvertedParameter += $transpiledTemplatePaths.transpiledParametersPath
                }
                $FilePath = $transpiledTemplatePaths.transpiledTemplatePath
            }

            try {
                # Create scope object from the given file path
                $scopeObject = New-AzOpsScope -Path $FilePath -StatePath $StatePath -ErrorAction Stop
            }
            catch {
                # Log a warning message if creating the scope object fails
                Write-AzOpsMessage -LogLevel Warning -LogString 'Invoke-AzOpsPush.Scope.Failed' -LogStringValues $FilePath -Target $FilePath -ErrorRecord $_
                continue
            }

            # Resolve ARM file association
            $resolvedArmFileAssociation = Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $FilePath -AzOpsMainTemplate $AzOpsMainTemplate -ConvertedTemplate $ConvertedTemplate -ConvertedParameter $ConvertedParameter
            if ($resolvedArmFileAssociation) {
                foreach ($fileAssociation in $resolvedArmFileAssociation) {
                    if ($true -eq $transpiledTemplatePaths.transpiledTemplateNew -and $fileAssociation.TemplateFilePath -eq $transpiledTemplatePaths.transpiledTemplatePath) {
                        $fileAssociation.TranspiledTemplateNew = $true
                    }
                    if ($true -eq $transpiledTemplatePaths.TranspiledParametersNew -and $fileAssociation.TemplateParameterFilePath -eq $transpiledTemplatePaths.transpiledParametersPath) {
                        $fileAssociation.TranspiledParametersNew = $true
                    }
                }
                return $resolvedArmFileAssociation
            }
        }
        function Resolve-ArmFileAssociation {
            [CmdletBinding()]
            param (
                [AzOpsScope]
                $ScopeObject,
                [string]
                $FilePath,
                [string]
                $AzOpsMainTemplate,
                [string[]]
                $ConvertedTemplate,
                [string[]]
                $ConvertedParameter
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
                TranspiledTemplateNew     = $false
                TemplateParameterFilePath = $null
                TranspiledParametersNew   = $false
                DeploymentName            = $null
                ScopeObject               = $ScopeObject
                Scope                     = $ScopeObject.Scope
            }

            $fileItem = Get-Item -Path $FilePath
            if ($fileItem.Extension -notin '.json' , '.bicep', '.bicepparam') {
                Write-AzOpsMessage -LogLevel Warning -LogString 'Invoke-AzOpsPush.Resolve.NoJson' -LogStringValues $fileItem.FullName -Target $ScopeObject
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
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -LogStringValues $FilePath
                            $templatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-3])"), '' -replace '\.parameters.json', '.json'
                            $bicepTemplatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-3])"), '' -replace '.parameters.json', '.bicep'
                        }
                        else {
                            $templatePath = $fileItem.FullName -replace '\.parameters.json', (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')
                            $bicepTemplatePath = $fileItem.FullName -replace '.parameters.json', '.bicep'
                        }
                        if (Test-Path $templatePath) {
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.FoundTemplate' -LogStringValues $FilePath, $templatePath
                            $result.TemplateFilePath = $templatePath
                            $newScopeObject = New-AzOpsScope -Path $result.TemplateFilePath -StatePath $StatePath -ErrorAction Stop
                            $result.ScopeObject = $newScopeObject
                            $result.Scope = $newScopeObject.Scope
                            return $result
                        }
                        elseif (Test-Path $bicepTemplatePath) {
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -LogStringValues $FilePath, $bicepTemplatePath
                            $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $bicepTemplatePath -SkipParam -ConvertedTemplate $ConvertedTemplate
                            $result.TranspiledTemplateNew = $transpiledTemplatePaths.transpiledTemplateNew
                            $result.TemplateFilePath = $transpiledTemplatePaths.transpiledTemplatePath
                            $newScopeObject = New-AzOpsScope -Path $result.TemplateFilePath -StatePath $StatePath -ErrorAction Stop
                            $result.ScopeObject = $newScopeObject
                            $result.Scope = $newScopeObject.Scope
                            return $result
                        }
                    }
                    { $_.EndsWith('.bicepparam') } {
                        if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $fileItem.FullName.Split('.')[-2] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) {
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -LogStringValues $FilePath
                            $bicepTemplatePath = $fileItem.FullName -replace (".$($fileItem.FullName.Split('.')[-2])"), '' -replace '\.bicepparam', '.bicep'
                        }
                        else {
                            $bicepTemplatePath = $fileItem.FullName -replace '\.bicepparam', '.bicep'
                        }
                        if (Test-Path $bicepTemplatePath) {
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -LogStringValues $FilePath, $bicepTemplatePath
                            $transpiledTemplatePaths = ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath $bicepTemplatePath -BicepParamTemplatePath $fileItem.FullName -ConvertedTemplate $ConvertedTemplate -ConvertedParameter $ConvertedParameter
                            $result.TranspiledTemplateNew = $transpiledTemplatePaths.transpiledTemplateNew
                            $result.TranspiledParametersNew = $transpiledTemplatePaths.transpiledParametersNew
                            $result.TemplateFilePath = $transpiledTemplatePaths.transpiledTemplatePath
                            $result.TemplateParameterFilePath = $transpiledTemplatePaths.transpiledParametersPath
                            $newScopeObject = New-AzOpsScope -Path $result.TemplateFilePath -StatePath $StatePath -ErrorAction Stop
                            $result.ScopeObject = $newScopeObject
                            $result.Scope = $newScopeObject.Scope
                            return $result
                        }
                    }
                }
                #endregion Directly Associated Template file exists

                #region Check in the main template file for a match
                Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Resolve.NotFoundTemplate' -LogStringValues $FilePath, $templatePath
                $mainTemplateItem = Get-Item $AzOpsMainTemplate
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.FromMainTemplate' -LogStringValues $mainTemplateItem.FullName

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
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.MainTemplate.Supported' -LogStringValues $effectiveResourceType, $mainTemplateItem.FullName
                    $result.TemplateFilePath = $mainTemplateItem.FullName
                    return $result
                }
                Write-AzOpsMessage -LogLevel Warning -LogString 'Invoke-AzOpsPush.Resolve.MainTemplate.NotSupported' -LogStringValues $effectiveResourceType, $mainTemplateItem.FullName -Target $ScopeObject
                return
                #endregion Check in the main template file for a match
                # All Code paths end the command
            }
            #endregion Case: Parameters File

            #region Case: Template File
            $result.TemplateFilePath = $fileItem.FullName
            $parameterPath = Join-Path $fileItem.Directory.FullName -ChildPath ($fileItem.BaseName + '.parameters' + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
            if (Test-Path -Path $parameterPath) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.ParameterFound' -LogStringValues $FilePath, $parameterPath
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
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.MultipleTemplateParameterFile' -LogStringValues $paramFile.FullName
                            $multiResult += Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $paramFile -AzOpsMainTemplate $AzOpsMainTemplate -ConvertedTemplate $ConvertedTemplate -ConvertedParameter $ConvertedParameter
                        }
                    }
                    if ($multiResult) {
                        # Return completed object
                        return $multiResult
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -LogStringValues $FilePath, $parameterPath
                    }

                }
            }
            else {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -LogStringValues $FilePath, $parameterPath
                if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true) {
                    # Check for template parameters without defaultValue
                    $defaultValueContent = Get-Content $FilePath
                    $missingDefaultParam = $defaultValueContent | jq '.parameters | with_entries(select(.value.defaultValue == null))' | ConvertFrom-Json -AsHashtable
                    if ($missingDefaultParam.Count -ge 1) {
                        # Skip template deployment when template parameters without defaultValue are found and no parameter file identified
                        $missingString = foreach ($item in $missingDefaultParam.Keys.GetEnumerator()) {"$item,"}
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Resolve.NotFoundParamFileDefaultValue' -LogStringValues $FilePath, ($missingString | Out-String -NoNewline)
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

        # Create array of strings to track bicep file conversion
        [string[]] $AzOpsTranspiledTemplate = @()
        [string[]] $AzOpsTranspiledParameter = @()

        # Remove lingering files from previous run
        $tempPath = [System.IO.Path]::GetTempPath()
        if ((Test-Path -Path ($tempPath + 'OUTPUT.md')) -or (Test-Path -Path ($tempPath + 'OUTPUT.json'))) {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsWhatIfOutput.WhatIfFile.Remove'
            Remove-Item -Path ($tempPath + 'OUTPUT.md') -Force -ErrorAction SilentlyContinue
            Remove-Item -Path ($tempPath + 'OUTPUT.json') -Force -ErrorAction SilentlyContinue
        }
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    process {
        if (-not $ChangeSet) { return }
        Assert-AzOpsInitialization -Cmdlet $PSCmdlet -StatePath $StatePath
        #Supported resource types for deletion
        $DeletionSupportedResourceType = (Get-PSFConfigValue -FullName 'AzOps.Core.DeletionSupportedResourceType')
        #region Categorize Input
        Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Deployment.Required'
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
            Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Change.AddModify'
            foreach ($item in $addModifySet) {
                Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Change.AddModify.File'-LogStringValues $item
            }
        }
        if ($DeleteSetContents -and $deleteSet) {
            Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Change.Delete'
            # Unique delimiter used to join, split and replace data in DeleteSetContents
            $delimiter = (New-Guid).Guid
            # Transform $DeleteSetContents for further processing
            $DeleteSetContents = $DeleteSetContents -join $delimiter -split "$delimiter-- " -replace $delimiter,""
            # Process each $deleteSet $item
            foreach ($item in $deleteSet) {
                Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Change.Delete.File' -LogStringValues $item
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
            Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Deploy.Subscription' -LogStringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.providerfeatures.json$') { continue }
            Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Deploy.ProviderFeature' -LogStringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.resourceproviders.json$') { continue }
            Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Deploy.ResourceProvider' -LogStringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        $newStateDeploymentCmd.End()
        #endregion Deploy State

        #region Create DeploymentList
        $deploymentList = foreach ($addition in $addModifySet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {
            # Create a list of deployment file associations using the New-AzOpsList function
            $deployFileAssociationList = New-AzOpsList -FilePath $addition -FileSet $addModifySet -AzOpsMainTemplate $AzOpsMainTemplate -ConvertedTemplate $AzOpsTranspiledTemplate -ConvertedParameter $AzOpsTranspiledParameter
            # Iterate through each file association in the list
            foreach ($fileAssociation in $deployFileAssociationList) {
                # Check if the transpiled template is new and add it to the collection if true
                if ($true -eq $fileAssociation.transpiledTemplateNew) {
                    $AzOpsTranspiledTemplate += $fileAssociation.TemplateFilePath
                }
                # Check if the transpiled parameters are new and add them to the collection if true
                if ($true -eq $fileAssociation.transpiledParametersNew) {
                    $AzOpsTranspiledParameter += $fileAssociation.TemplateParameterFilePath
                }
            }
            # Output the list of file associations for the current addition
            $deployFileAssociationList
        }
        #endregion Create DeploymentList

        #region Create DeletionList
        $deletionList = foreach ($deletion in $deleteSet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {
            # Create a list of deletion file associations using the New-AzOpsList function
            $deletionFileAssociationList = New-AzOpsList -FilePath $deletion -FileSet $deleteSet -AzOpsMainTemplate $AzOpsMainTemplate -ConvertedTemplate $AzOpsTranspiledTemplate -ConvertedParameter $AzOpsTranspiledParameter
            # Iterate through each file association in the list
            foreach ($fileAssociation in $deletionFileAssociationList) {
                # Check if the transpiled template is new and add it to the collection if true
                if ($true -eq $fileAssociation.transpiledTemplateNew) {
                    $AzOpsTranspiledTemplate += $fileAssociation.TemplateFilePath
                }
                # Check if the transpiled parameters are new and add them to the collection if true
                if ($true -eq $fileAssociation.transpiledParametersNew) {
                    $AzOpsTranspiledParameter += $fileAssociation.TemplateParameterFilePath
                }
            }
            # Output the list of file associations for the current deletion
            $deletionFileAssociationList
        }
        #endregion Create DeletionList

        #Required deletion order
        $deletionListPriority = @(
            "locks",
            "policyExemptions",
            "policyAssignments",
            "policySetDefinitions",
            "policyDefinitions",
            "resourceGroups",
            "managementGroups"
        )

        #Sort 'deletionList' based on 'deletionListPriority'
        $deletionList = $deletionList | Sort-Object -Property {
            $priorityIndex = $deletionListPriority.IndexOf($_.ScopeObject.Resource)
            if ($priorityIndex -eq -1) {
                # Set a default priority for items not found in deletionListPriority
                return [int]::MaxValue
            }
            else {
                return $priorityIndex
            }
        }

        #If addModifySet exists and no deploymentList has been generated at the same time as the StatePath root has additional directories and AllowMultipleTemplateParameterFiles is default false, exit with terminating error
        if (($addModifySet -and -not $deploymentList) -and (Get-ChildItem -Path $StatePath -Directory) -and ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $false)) {
            Write-AzOpsMessage -LogLevel Critical -LogString 'Invoke-AzOpsPush.DeploymentList.NotFound'
            throw
        }

        #Starting deployment
        $WhatIfPreference = $WhatIfPreferenceState
        $uniqueProperties = 'Scope', 'DeploymentName', 'TemplateFilePath', 'TemplateParameterFilePath'
        $uniqueDeployment = $deploymentList | Select-Object $uniqueProperties -Unique
        $deploymentResult = @()

        if ($uniqueDeployment) {
            #Determine what deployment pattern to adopt serial or parallel
            if ((Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and (Get-PSFConfigValue -FullName 'AzOps.Core.ParallelDeployMultipleTemplateParameterFiles') -eq $true) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.ParallelCondition'
                # Group deployments based on TemplateFilePath
                $groups = $uniqueDeployment | Group-Object -Property TemplateFilePath | Where-Object { $_.Count -ge '2' -and $_.Name -ne $(Get-Item $AzOpsMainTemplate).FullName }
                if ($groups) {
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.ParallelGroup'
                    $processedTargets = @()
                    # Process each deployment and evaluate serial or parallel deployment pattern
                    foreach ($deployment in $uniqueDeployment) {
                        if ($deployment.TemplateFilePath -in $groups.Name -and $deployment -notin $processedTargets) {
                            # Deployment part of group association for parallel processing, process entire group as parallel deployment
                            $targets = $($groups | Where-Object { $_.Name -eq $deployment.TemplateFilePath }).Group
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.Parallel' -LogStringValues $deployment.TemplateFilePath, $targets.Count
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
                            } -UseNewRunspace
                            Clear-PSFMessage
                            # Add targets to processed list to avoid duplicate deployment
                            $processedTargets += $targets
                        }
                        elseif ($deployment -notin $processedTargets) {
                            # Deployment not part of group association for parallel processing, process this as serial deployment
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.Serial' -LogStringValues $deployment.Count
                            $deploymentResult += $deployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
                        }
                        else {
                            # Deployment already processed by group association from parallel processing, skip this duplicate deployment
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.Skip' -LogStringValues $deployment.TemplateFilePath, $deployment.TemplateParameterFilePath
                        }
                    }
                }
                else {
                    # No deployments with matching TemplateFilePath identified
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.Serial' -LogStringValues $deployment.Count
                    $deploymentResult += $uniqueDeployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
                }
            } else {
                # Perform serial deployment only
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsPush.Deployment.Serial' -LogStringValues $uniqueDeployment.Count
                $deploymentResult += $uniqueDeployment | New-AzOpsDeployment -WhatIf:$WhatIfPreference
            }

            if ($deploymentResult) {
                # Output deploymentResult outside module
                $deploymentResult
                #Process deploymentResult and output result
                foreach ($result in $deploymentResult) {
                    Set-AzOpsWhatIfOutput -FilePath $result.filePath -ParameterFilePath $result.parameterFilePath -Results $result.results
                }
            }
        }

        #Removal of Supported resourceTypes
        $removalJob = $deletionList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment -WhatIf:$WhatIfPreference
        if ($removalJob.FullyQualifiedResourceId.Count -gt 0) {
            Clear-PSFMessage
            # Identify failed removal attempts for potential retries
            $retry = $removalJob | Where-Object { $_.Status -eq 'failed' }
            # If there are retries, log and attempt them again
            if ($retry) {
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Invoke-AzOpsPush.Deletion.Retry' -LogStringValues $retry.Count
                Start-Sleep -Seconds 30
                # Reset the status of failed attempts and perform recursive removal
                foreach ($try in $retry) { $try.Status = $null }
                $removeActionRecursive = Remove-AzResourceRawRecursive -InputObject $retry
                $removeActionFail = $removeActionRecursive | Where-Object { $_.Status -eq 'failed' }
                # If removal fails, log and attempt to fetch the resource causing the failure
                if ($removeActionFail) {
                    Start-Sleep -Seconds 90
                    $throwFail = $false
                    # Check each failed removal and attempt to get the associated resource
                    foreach ($fail in $removeActionFail) {
                        $resource = $null
                        Set-AzOpsContext -ScopeObject $fail.ScopeObject
                        # Determine if the resource is a lock or a regular resource
                        if ($fail.FullyQualifiedResourceId -match '^/subscriptions/.*/providers/Microsoft.Authorization/locks' -or $fail.FullyQualifiedResourceId -match '^/subscriptions/.*/resourceGroups/.*/providers/Microsoft.Authorization/locks') {
                            $resource = Get-AzResourceLock | Where-Object { $_.ResourceId -eq $fail.FullyQualifiedResourceId } -ErrorAction SilentlyContinue
                        }
                        else {
                            $resource = Get-AzResource -ResourceId $fail.FullyQualifiedResourceId -ErrorAction SilentlyContinue
                        }
                        # If the resource is found, log the failure
                        if ($resource) {
                            $throwFail = $true
                            Write-AzOpsMessage -LogLevel Critical -LogString 'Invoke-AzOpsPush.Deletion.Failed' -LogStringValues $fail.FullyQualifiedResourceId, $fail.TemplateFilePath, $fail.TemplateParameterFilePath
                        }
                    }
                    # If any failures occurred, throw an exception
                    if ($throwFail) {
                        throw
                    }
                }
            }
        }
        # If there are missing dependencies, log the error and throw an exception
        if ($removalJob.dependencyMissing -eq $true) {
            Write-AzOpsMessage -LogLevel Critical -LogString 'Invoke-AzOpsPush.Dependency.Missing'
            throw
        }
        $stopWatch.Stop()
        Write-AzOpsMessage -LogLevel Important -LogString 'Invoke-AzOpsPush.Duration' -LogStringValues $stopWatch.Elapsed -Metric $stopWatch.Elapsed.TotalSeconds -MetricName 'AzOpsPush Time'
        Clear-PSFMessage
    }
}