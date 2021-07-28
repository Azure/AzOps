function Invoke-AzOpsPush {

    <#
        .SYNOPSIS
            Applies a change to Azure from the AzOps configuration.
        .DESCRIPTION
            Applies a change to Azure from the AzOps configuration.
        .PARAMETER ChangeSet
            Set of changes from the last execution that need to be applied.
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .PARAMETER AzOpsMainTemplate
            Path to the main template used by AzOps
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

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [string]
        $AzOpsMainTemplate = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate')
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
            #endregion Initialization Prep

            #region Case: Parameters File
            if ($fileItem.Name.EndsWith('.parameters.json')) {
                $result.TemplateParameterFilePath = $fileItem.FullName
                $deploymentName = $fileItem.Name -replace (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'), ''
                if ($deploymentName.Length -gt 58) { $deploymentName = $deploymentName.SubString(0, 58) }
                $result.DeploymentName = "AzOps-$deploymentName"

                #region Directly Associated Template file exists
                $templatePath = $fileItem.FullName -replace '.parameters.json', (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')
                if (Test-Path $templatePath) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.FoundTemplate' -StringValues $FilePath, $templatePath
                    $result.TemplateFilePath = $templatePath
                    return $result
                }
                #endregion Directly Associated Template file exists

                #region Directly Associated bicep template exists
                $bicepTemplatePath = $fileItem.FullName -replace '.parameters.json', '.bicep'
                if (Test-Path $bicepTemplatePath) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.FoundBicepTemplate' -StringValues $FilePath, $bicepTemplatePath
                    $result.TemplateFilePath = $bicepTemplatePath
                    return $result
                }
                #endregion Directly Associated bicep template exists

                #region Check in the main template file for a match
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.NotFoundTemplate' -StringValues $FilePath, $templatePath
                $mainTemplateItem = Get-Item $AzOpsMainTemplate
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.FromMainTemplate' -StringValues $mainTemplateItem.FullName

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
                    Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.MainTemplate.Supported' -StringValues $effectiveResourceType, $AzOpsMainTemplate.FullName
                    $result.TemplateFilePath = $mainTemplateItem.FullName
                    return $result
                }
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsPush.Resolve.MainTemplate.NotSupported' -StringValues $effectiveResourceType, $AzOpsMainTemplate.FullName -Tag pwsh -FunctionName 'Invoke-AzOpsPush' -Target $ScopeObject
                return
                #endregion Check in the main template file for a match
                # All Code paths end the command
            }
            #endregion Case: Parameters File

            #region Case: Template File
            $result.TemplateFilePath = $fileItem.FullName
            $parameterPath = Join-Path $fileItem.Directory.FullName -ChildPath ($fileItem.BaseName + '.parameters' + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
            if (Test-Path -Path $parameterPath) {
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.ParameterFound' -StringValues $FilePath, $parameterPath
                $result.TemplateParameterFilePath = $parameterPath
            }
            else {
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.ParameterNotFound' -StringValues $FilePath, $parameterPath
            }

            $deploymentName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
            if ($deploymentName.Length -gt 58) { $deploymentName = $deploymentName.SubString(0, 58) }
            $result.DeploymentName = "AzOps-$deploymentName"

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

        #region Categorize Input
        Write-PSFMessage @common -String 'Invoke-AzOpsPush.Deployment.Required'
        $deleteSet = @()
        $addModifySet = foreach ($change in $ChangeSet) {
            $operation, $filename = ($change -split "`t")[0, -1]
            if ($operation -eq 'D') {
                $deleteSet += $filename
                continue
            }
            if ($operation -in 'A', 'M', 'R' -or $operation -match '^R0[0-9][1-9]$') { $filename }
        }
        if ($deleteSet) { $deleteSet = $deleteSet | Sort-Object }
        if ($addModifySet) { $addModifySet = $addModifySet | Sort-Object }
        # TODO: Clarify what happens with the deletes - not used after reporting them

        Write-PSFMessage @common -String 'Invoke-AzOpsPush.Change.AddModify'
        foreach ($item in $addModifySet) {
            Write-PSFMessage @common -String 'Invoke-AzOpsPush.Change.AddModify.File' -StringValues $item
        }
        Write-PSFMessage @common -String 'Invoke-AzOpsPush.Change.Delete'
        foreach ($item in $deleteSet) {
            Write-PSFMessage @common -String 'Invoke-AzOpsPush.Change.Delete.File' -StringValues $item
        }
        #endregion Categorize Input

        #region Deploy State
        $common.Tag = 'pwsh'
        # Nested Pipeline allows economizing on New-AzOpsStateDeployment having to run its "begin" block once only
        $newStateDeploymentCmd = { New-AzOpsStateDeployment -StatePath $StatePath }.GetSteppablePipeline()
        $newStateDeploymentCmd.Begin($true)
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.subscription.json$') { continue }
            Write-PSFMessage @common -String 'Invoke-AzOpsPush.Deploy.Subscription' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.providerfeatures.json$') { continue }
            Write-PSFMessage @common -String 'Invoke-AzOpsPush.Deploy.ProviderFeature' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        foreach ($addition in $addModifySet) {
            if ($addition -notmatch '/*.resourceproviders.json$') { continue }
            Write-PSFMessage @common -String 'Invoke-AzOpsPush.Deploy.ResourceProvider' -StringValues $addition -Target $addition
            $newStateDeploymentCmd.Process($addition)
        }
        $newStateDeploymentCmd.End()
        #endregion Deploy State

        $deploymentList = foreach ($addition in $addModifySet | Where-Object { $_ -match ((Get-Item $StatePath).Name) }) {

            # Avoid duplicate entries in the deployment list
            if ($addition.EndsWith(".parameters.json")) {
                if ($addModifySet -contains $addition.Replace(".parameters.json", ".json")) {
                    continue
                }
            }

            # Handle Bicep templates
            if ($addition.EndsWith(".bicep")) {
                Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
                $transpiledTemplatePath = $addition -replace '.bicep', '.json'
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Resolve.ConvertBicepTemplate' -StringValues $addModifySet, $transpiledTemplatePath
                Invoke-AzOpsNativeCommand -ScriptBlock { bicep build $addition --outfile $transpiledTemplatePath }
                $addition = $transpiledTemplatePath
            }

            try { $scopeObject = New-AzOpsScope -Path $addition -StatePath $StatePath -ErrorAction Stop }
            catch {
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Scope.Failed' -StringValues $addition, $StatePath -Target $addition -ErrorRecord $_
                continue
            }
            if (-not $scopeObject) {
                Write-PSFMessage @common -String 'Invoke-AzOpsPush.Scope.NotFound' -StringValues $addition, $StatePath -Target $addition
                continue
            }

            Resolve-ArmFileAssociation -ScopeObject $scopeObject -FilePath $addition -AzOpsMainTemplate $AzOpsMainTemplate
        }

        $WhatIfPreference = $WhatIfPreferenceState

        #Starting Tenant Deployment
        $uniqueProperties = 'Scope', 'DeploymentName', 'TemplateFilePath', 'TemplateParameterFilePath'
        $deploymentList | Select-Object $uniqueProperties -Unique | Sort-Object -Property TemplateParameterFilePath | New-AzOpsDeployment -WhatIf:$WhatIfPreference
    }

}