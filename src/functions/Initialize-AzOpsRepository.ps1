﻿function Initialize-AzOpsRepository {

    <#
        .SYNOPSIS
            Setup a repository for the AzOps workflow, based off templates and an existing Azure deployment.
        .DESCRIPTION
            Setup a repository for the AzOps workflow, based off templates and an existing Azure deployment.
        .PARAMETER SkipPolicy
            Skip discovery of policies for better performance.
        .PARAMETER SkipRole
            Skip discovery of role.
        .PARAMETER SkipResourceGroup
            Skip discovery of resource groups resources for better performance
        .PARAMETER InvalidateCache
            Invalidate cached subscriptions and Management Groups and do a full discovery.
        .PARAMETER GeneralizeTemplates
            Will generalize json templates (only used when generating azopsreference).
        .PARAMETER ExportRawTemplate
            Export generic templates without embedding them in the parameter block.
        .PARAMETER Rebuild
            Delete all .AzState folders inside AzOpsState directory.
        .PARAMETER Force
            Delete $script:AzOpsState directory.
        .PARAMETER PartialMgDiscovery
            Accept working with only a subset of management groups in the entire hierarchy.
            Needed when lacking root access.
        .PARAMETER PartialMgDiscoveryRoot
            The subset of management groups in the entire hierarchy with which to work.
            Needed when lacking root access.
        .PARAMETER StatePath
            The root folder under which to write the resource json.
        .EXAMPLE
            > Initialize-AzOpsRepository
            Setup a repository for the AzOps workflow, based off templates and an existing Azure deployment.
    #>

    [CmdletBinding()]
    param (
        [switch]
        $SkipPolicy = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipPolicy'),

        [switch]
        $SkipRole = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipRole'),

        [switch]
        $SkipResourceGroup = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipResourceGroup'),

        [switch]
        $InvalidateCache = (Get-PSFConfigValue -FullName 'AzOps.Core.InvalidateCache'),

        [switch]
        $GeneralizeTemplates = (Get-PSFConfigValue -FullName 'AzOps.Core.GeneralizeTemplates'),

        [switch]
        $ExportRawTemplate = (Get-PSFConfigValue -FullName 'AzOps.Core.ExportRawTemplate'),

        [switch]
        $Rebuild,

        [switch]
        $Force,

        [switch]
        $PartialMgDiscovery = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot'),

        [string[]]
        $PartialMgDiscoveryRoot = (Get-PSFConfigValue -FullName 'AzOps.Core.PartialMgDiscoveryRoot'),

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State'),

        [string]
        $TemplateParameterFileSuffix = (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')
    )

    begin {
        #region Initialize & Prepare
        Write-PSFMessage -String 'Initialize-AzOpsRepository.Initialization.Starting'
        if (-not $SkipRole) {
            try {
                Write-PSFMessage -String 'Initialize-AzOpsRepository.Validating.UserRole'
                Get-AzADUser -First 1 -ErrorAction Stop
                Write-PSFMessage -String 'Initialize-AzOpsRepository.Validating.UserRole.Success'
            }
            catch {
                Write-PSFMessage -Level Warning -String 'Initialize-AzOpsRepository.Validating.UserRole.Failed'
                $SkipRole = $true
            }
        }

        $parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Inherit -Include InvalidateCache, PartialMgDiscovery, PartialMgDiscoveryRoot
        Initialize-AzOpsEnvironment @parameters

        Assert-AzOpsInitialization -Cmdlet $PSCmdlet -StatePath $StatePath

        $tenantId = (Get-AzContext).Tenant.Id
        Write-PSFMessage -String 'Initialize-AzOpsRepository.Tenant' -StringValues $tenantId
        Write-PSFMessage -String 'Initialize-AzOpsRepository.TemplateParameterFileSuffix' -StringValues (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix')

        Write-PSFMessage -String 'Initialize-AzOpsRepository.Initialization.Completed'
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        #endregion Initialize & Prepare
    }

    process {
        #region Existing Content
        if (Test-Path $StatePath) {
            $migrationRequired = (Get-ChildItem -Recurse -Force -Path $StatePath -File | Where-Object {
                    $_.Name -like $("Microsoft.Management_managementGroups-" + $tenantId + $TemplateParameterFileSuffix)
                } | Select-Object -ExpandProperty FullName -First 1) -notmatch '\((.*)\)'
            if ($migrationRequired) {
                Write-PSFMessage -String 'Initialize-AzOpsRepository.Migration.Required'
            }

            if ($Force -or $migrationRequired) {
                Invoke-PSFProtectedCommand -ActionString 'Initialize-AzOpsRepository.Deleting.State' -ActionStringValues $StatePath -Target $StatePath -ScriptBlock {
                    Remove-Item -Path $StatePath -Recurse -Force -Confirm:$false -ErrorAction Stop
                } -EnableException $true -PSCmdlet $PSCmdlet
            }
            if ($Rebuild) {
                Invoke-PSFProtectedCommand -ActionString 'Initialize-AzOpsRepository.Rebuilding.State' -ActionStringValues $StatePath -Target $StatePath -ScriptBlock {
                    Get-ChildItem -Path $StatePath -Directory -Recurse -Force -Include '.AzState' -ErrorAction Stop | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction Stop
                } -EnableException $true -PSCmdlet $PSCmdlet
            }
        }
        #endregion Existing Content

        #region Root Scopes
        $rootScope = '/providers/Microsoft.Management/managementGroups/{0}' -f $tenantId
        if ($script:AzOpsPartialRoot.id) {
            $rootScope = $script:AzOpsPartialRoot.id | Sort-Object -Unique
        }

        foreach ($root in $rootScope) {
            # Create AzOpsState Structure recursively
            Save-AzOpsManagementGroupChildren -Scope $root -StatePath $StatePath

            # Discover Resource at scope recursively
            $parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Inherit -Include SkipPolicy, SkipRole, SkipResourceGroup, ExportRawTemplate, StatePath
            Get-AzOpsResourceDefinition -Scope $root @parameters
        }
        #endregion Root Scopes
    }

    end {
        $stopWatch.Stop()
        Write-PSFMessage -String 'Initialize-AzOpsRepository.Duration' -StringValues $stopWatch.Elapsed -Data @{ Elapsed = $stopWatch.Elapsed }
    }

}