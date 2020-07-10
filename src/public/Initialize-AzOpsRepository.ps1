<#
.SYNOPSIS
    This cmdlet initializes the azops repository and takes a snapshot of the entire Azure environment from MG all the way down to resource level.
.DESCRIPTION
    When the initialization is complete, the "azops" folder will have a folder structure representing the entire Azure environment from root Management Group down to resources.
    Note that each .AzState folder will contain a snapshot of the resources/policies in that scope.
.EXAMPLE
    # Recursively discover all resources that the current user/principal has access to.
    Initialize-AzOpsRepository
.EXAMPLE
    # Recursively discover all resources that the current user/principal has access to, but exclude policy discovery for better performance and always invalidate the cache
    Initialize-AzOpsRepository -SkipPolicy -InvalidateCache -Verbose
.EXAMPLE
    # Recursively discover all resources that the current user/principal has access to, but exclude policy and resource/resource group discovery for better performance
    Initialize-AzOpsRepository -SkipPolicy -SkipResourceGroup -Verbose
.INPUTS
    None
.OUTPUTS
    .\azops-folder in repo with all azure resources reflected
     # Example of structure generated
    |-- azops
    |-- 43a8a113-b0e1-4b17-b6ab-68c8925bf817
       |-- .AzState
       |-- Tailspin
           |-- .AzState
           |-- Tailspin-decomissioned
           |   |-- .AzState
           |-- Tailspin-Landing Zones
           |   |-- .AzState
           |   |-- Tailspin-corp
           |   |   |-- .AzState
           |   |-- Tailspin-online
           |   |   |-- .AzState
           |   |-- Tailspin-sap
           |       |-- .AzState
           |-- Tailspin-platform
           |   |-- .AzState
           |   |-- Tailspin-connectivity
           |   |   |-- .AzState
           |   |-- Tailspin-identity
           |   |   |-- .AzState
           |   |-- Tailspin-management
           |       |-- .AzState
           |-- Tailspin-sandboxes
               |-- .AzState
#>

function Initialize-AzOpsRepository {

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars','global:AzOpsState')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars','global:AzOpsAzManagementGroup')]
    [CmdletBinding()]
    [OutputType()]
    param(
        # Skip discovery of policies for better performance.
        [Parameter(Mandatory = $false)]
        [switch]$SkipPolicy,
        # Skip discovery of resource groups resources for better performance.
        [Parameter(Mandatory = $false)]
        [switch]$SkipResourceGroup,
        # Invalidate cached subscriptions and Management Groups and do a full discovery.
        [Parameter(Mandatory = $false)]
        [switch]$InvalidateCache,
        # Will generalize json templates (only used when generating azopsreference).
        [Parameter(Mandatory = $false)]
        [switch]$GeneralizeTemplates,
        # Export generic templates without embedding them in the parameter block.
        [Parameter(Mandatory = $false)]
        [switch]$ExportRawTemplate,
        # Delete all .AzState folders inside AzOpsState directory.
        [Parameter(Mandatory = $false)]
        [switch]$Rebuild,
        # Delete $global:AzOpsState directory.
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsRepository" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        # Set environment variable InvalidateCache to 1 if switch InvalidateCache switch has been used
        if ($PSBoundParameters['InvalidateCache']) {
            $env:InvalidateCache = 1
        }
        # Set environment variable GeneralizeTemplates to 1 if switch GeneralizeTemplates switch has been used
        if ($PSBoundParameters['GeneralizeTemplates']) {
            $env:GeneralizeTemplates = 1
        }
        # Set environment variable ExportRawTemplate to 1 if switch ExportRawTemplate switch has been used
        if ($PSBoundParameters['ExportRawTemplate']) {
            $env:ExportRawTemplate = 1
        }
        # Initialize Global Variables if not set
        if (-not (Test-AzOpsVariables)) {
            Initialize-AzOpsGlobalVariables
        }
        # Get tenant id for current Az Context
        $TenantId = (Get-AzContext).Tenant.Id
        Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Tenant ID: $TenantID"
        # Start stopwatch for measuring time
        $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsRepository" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Set/find the root scope based on TenantID
        $TenantRootId = '/providers/Microsoft.Management/managementGroups/{0}' -f $TenantId
        Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Tenant root Management Group is: $TenantID"

        if ($PSBoundParameters['Force']) {
            # Force will delete $global:AzOpsState directory
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Forcing deletion of AzOpsState directory. All artefacts will be lost"
            if (Test-Path -Path $global:AzOpsState) {
                Remove-Item $global:AzOpsState -Recurse -Force -Confirm:$false -ErrorAction Stop
                Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "AzOpsState directory deleted: $global:AzOpsState"
            }
            else {
                Write-AzOpsLog -Level Warning -Topic "Initialize-AzOpsRepository" -Message "AzOpsState directory not found: $global:AzOpsState"
            }
        }
        if ($Rebuild) {
            # Rebuild will delete .AzState folder inside AzOpsState directory.
            # This will leave existing folder as it is so customer artefact are preserved upon recreating.
            # If Subscription move and deletion activity happened in-between, it will not reconcile to on safe-side to wrongly associate artefact at incorrect scope.
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Rebuilding AzOpsState. Purging all .AzState directories"
            if (Test-Path -Path $global:AzOpsState) {
                Get-ChildItem $global:AzOpsState -Directory -Recurse -Force -Include '.AzState' | Remove-Item -Force -Recurse
                Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Purged all .AzState directories under path: $global:AzOpsState"
            }
            else {
                Write-AzOpsLog -Level Warning -Topic "Initialize-AzOpsRepository" -Message "AzOpsState directory not found: $global:AzOpsState"
            }
        }

        # Set AzOpsScope root scope based on tenant root id
        $RootScope = $global:AzOpsAzManagementGroup | Where-Object -FilterScript { $_.Id -eq $TenantRootId }
        if ($RootScope) {
            $RootScopeId = $RootScope.Id
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Set root Management Group scope: $RootScopeId"
            # Create AzOpsState Structure recursively
            Save-AzOpsManagementGroupChildren -scope $RootScopeId
            # Discover Resource at scope recursively
            Get-AzOpsResourceDefinitionAtScope -scope $RootScopeId -SkipPolicy:$SkipPolicy -SkipResourceGroup:$SkipResourceGroup
        }
        else {
            Write-Error "Root Management Group Not Found"
        }
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsRepository" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
        $StopWatch.Stop()
        Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsRepository" -Message "Time elapsed: $($stopwatch.elapsed)"
    }

}
