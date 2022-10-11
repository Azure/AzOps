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
            if ($fileItem.Extension -notin '.json' , '.bicep') {
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsPush.Resolve.NoJson' -StringValues $fileItem.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsPush' -Target $ScopeObject
                return
            }

            # Generate deterministic id for DefaultDeploymentRegion to overcome deployment issues when changing DefaultDeploymentRegion
            $deploymentRegionId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)
            #endregion Initialization Prep

            #region Case: Parameters File
            if ($fileItem.Name.EndsWith('.parameters.json')) {
                $result.TemplateParameterFilePath = $fileItem.FullName
                $deploymentName = $fileItem.Name -replace (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'), '' -replace ' ', '_'
                if ($deploymentName.Length -gt 53) { $deploymentName = $deploymentName.SubString(0, 53) }
                $result.DeploymentName = 'AzOps-{0}-{1}' -f $deploymentName, $deploymentRegionId

                #region Directly Associated Template file exists
                $templatePath = $fileItem.FullName -replace '.parameters.json', (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')
                if (Test-Path $templatePath) {
                    Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FoundTemplate' -StringValues $FilePath, $templatePath
                    $result.TemplateFilePath = $templatePath
                    return $result
                }
                #endregion Directly Associated Template file exists

                #region Directly Associated bicep template exists
                $bicepTemplatePath = $fileItem.FullName -replace '.parameters.json', '.bicep'
                if (Test-Path $bicepTemplatePath) {
                    Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -StringValues $FilePath, $bicepTemplatePath
                    $result.TemplateFilePath = $bicepTemplatePath
                    return $result
                }
                #endregion Directly Associated bicep template exists

                #region Check in the main template file for a match
                Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Resolve.NotFoundTemplate' -StringValues $FilePath, $templatePath
                $mainTemplateItem = Get-Item $AzOpsMainTemplate
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.FromMainTemplate' -StringValues $mainTemplateItem.FullName

                # Determine Resource Type in Parameter file
                $templateParameterFileHashtable = Get-Content -Path $fileItem.FullName | ConvertFrom-Json -AsHashtable
                $effectiveResourceType = $null
                if ($templateParameterFileHashtable.Keys -contains "`$schema") {
                    if ($templateParameterFileHashtable.parameters.input.value.Keys -contains "Type") {
                        # ManagementGroup and Subscription
                        $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.Type
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
            else {
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -StringValues $FilePath, $parameterPath
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
    }

    process {
        if (-not $ChangeSet) { return }
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

        Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.AddModify'
        foreach ($item in $addModifySet) {
            Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.AddModify.File' -StringValues $item
        }
        Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.Delete'
        if ($DeleteSetContents -and $deleteSet) {
            $DeleteSetContents = $DeleteSetContents -join "" -split "-- " | Where-Object { $_ }
            foreach ($item in $deleteSet) {
                Write-PSFMessage -Level Important @common -String 'Invoke-AzOpsPush.Change.Delete.File' -StringValues $item
                foreach ($content in $DeleteSetContents) {
                    if ($content.Contains($item)) {
                        $jsonValue = $content.replace($item, "")
                        if (-not(Test-Path -Path (Split-Path -Path $item))) {
                            New-Item -Path (Split-Path -Path $item) -ItemType Directory | Out-Null
                        }
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

            # Handle Bicep templates
            if ($addition.EndsWith(".bicep")) {
                Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
                $transpiledTemplatePath = $addition -replace '\.bicep', '.json'
                Write-PSFMessage -Level Verbose @common -String 'Invoke-AzOpsPush.Resolve.ConvertBicepTemplate' -StringValues $addition, $transpiledTemplatePath
                Invoke-AzOpsNativeCommand -ScriptBlock { bicep build $addition --outfile $transpiledTemplatePath }
                $addition = $transpiledTemplatePath
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
            if ($templateContent.$schemavalue -like "*deploymentParameters.json#" -and (-not($templateContent.parameters.input.value.ResourceType -in $DeletionSupportedResourceType))) {
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
        #Required order for deletion
        $deletionListPriority = @(
            "policyExemptions",
            "policyAssignments",
            "policySetDefinitions",
            "policyDefinitions"
        )
        $deletionList = $deletionList | Sort-Object {$deletionListPriority.IndexOf($_.ScopeObject.Resource)}
        $WhatIfPreference = $WhatIfPreferenceState

        #If addModifySet exists and no deploymentList has been generated at the same time as the StatePath root has additional directories, exit with terminating error
        if (($addModifySet -and -not $deploymentList) -and (Get-ChildItem -Path $StatePath -Directory)) {
            Write-PSFMessage -Level Critical @common -String 'Invoke-AzOpsPush.DeploymentList.NotFound'
            throw
        }

        #Starting Tenant Deployment
        $uniqueProperties = 'Scope', 'DeploymentName', 'TemplateFilePath', 'TemplateParameterFilePath'
        $deploymentList | Select-Object $uniqueProperties -Unique | New-AzOpsDeployment -WhatIf:$WhatIfPreference

        #Removal of Supported resourceTypes
        $uniqueProperties = 'Scope', 'TemplateFilePath', 'TemplateParameterFilePath'
        $removalJob = $deletionList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment -WhatIf:$WhatIfPreference
        if ($removalJob.dependencyMissing -eq $true) {
            Write-PSFMessage -Level Critical @common -String 'Invoke-AzOpsPush.Dependency.Missing'
            throw
        }
    }
}