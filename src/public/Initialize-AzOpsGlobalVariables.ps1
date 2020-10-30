<#
.SYNOPSIS
    Initializes the environment and global variables variables required for the AzOps cmdlets.
.DESCRIPTION
    Initializes the environment and global variables variables required for the AzOps cmdlets.
    Key / Values in the AzOpsEnvVariables hashtable will be set as environment variables and global variables.
    All Management Groups and Subscription that the user/service principal have access to will be discovered and added to their respective variables.
.EXAMPLE
    Initialize-AzOpsGlobalVariables
.INPUTS
    None
.OUTPUTS
    - Global variables and environment variables as defined in @{ $AzOpsEnvVariables }
    - $global:AzOpsAzManagementGroup as well as $global:AzOpsSubscriptions with all subscriptions and Management Groups that was discovered
#>

function Initialize-AzOpsGlobalVariables {

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsInvalidateCache')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsAzManagementGroup')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSubscriptions')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsPartialRoot')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsState')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSupportPartialMgDiscovery')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsPartialMgDiscoveryRoot')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsExcludedSubOffer')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsExcludedSubState')]
    [CmdletBinding()]
    [OutputType()]
    param (
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsGlobalVariables" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")

        # Validate that Azure Context is available
        $AllAzContext = Get-AzContext -ListAvailable
        if (-not($AllAzContext)) {
            Write-AzOpsLog -Level Error -Topic "Initialize-AzOpsGlobalVariables" -Message "No context available in Az PowerShell. Please use Connect-AzAccount and connect before using the command"
            throw
        }

        # Required environment variables hashtable with default values
        $AzOpsEnvVariables = @{
            # AzOps
            AZOPS_STATE                        = @{ AzOpsState = (Join-Path $pwd -ChildPath "azops") } # Folder to store AzOpsState artefact
            AZOPS_MAIN_TEMPLATE                = @{ AzOpsMainTemplate = "$PSScriptRoot\..\..\template\template.json" } # Main template json
            AZOPS_STATE_CONFIG                 = @{ AzOpsStateConfig = "$PSScriptRoot\..\AzOpsStateConfig.json" } # Configuration file for resource serialization
            AZOPS_ENROLLMENT_ACCOUNT           = @{ AzOpsEnrollmentAccountPrincipalName = $null }
            AZOPS_EXCLUDED_SUB_OFFER           = @{ AzOpsExcludedSubOffer = "AzurePass_2014-09-01,FreeTrial_2014-09-01,AAD_2015-09-01" } # Excluded QuotaIDs as per https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/understand-cost-mgt-data#supported-microsoft-azure-offers
            AZOPS_EXCLUDED_SUB_STATE           = @{ AzOpsExcludedSubState = "Disabled,Deleted,Warned,Expired" } # Excluded subscription states as per https://docs.microsoft.com/en-us/rest/api/resources/subscriptions/list#subscriptionstate
            AZOPS_OFFER_TYPE                   = @{ AzOpsOfferType = 'MS-AZR-0017P' }
            AZOPS_DEFAULT_DEPLOYMENT_REGION    = @{ AzOpsDefaultDeploymentRegion = 'northeurope' } # Default deployment region for state deployments (ARM region, not region where a resource is deployed)
            AZOPS_INVALIDATE_CACHE             = @{ AzOpsInvalidateCache = 1 } # Invalidates cache and ensures that Management Groups and Subscriptions are re-discovered
            AZOPS_GENERALIZE_TEMPLATES         = @{ AzOpsGeneralizeTemplates = 0 } # Invalidates cache and ensures that Management Groups and Subscriptions are re-discovered
            AZOPS_EXPORT_RAW_TEMPLATES         = @{ AzOpsExportRawTemplate = 0 }
            AZOPS_IGNORE_CONTEXT_CHECK         = @{ AzOpsIgnoreContextCheck = 0 } # If set to 1, skip AAD tenant validation == 1
            AZOPS_THROTTLE_LIMIT               = @{ AzOpsThrottleLimit = 10 } # Throttle limit used in Foreach-Object -Parallel for resource/subscription discovery
            AZOPS_SUPPORT_PARTIAL_MG_DISCOVERY = @{ AzOpsSupportPartialMgDiscovery = $null } # Enable partial discovery
            AZOPS_PARTIAL_MG_DISCOVERY_ROOT    = @{ AzOpsPartialMgDiscoveryRoot = $null } # Used in combination with AZOPS_SUPPORT_PARTIAL_MG_DISCOVERY, example value (comma separated, not real array due to env variable constraints) "Contoso,Tailspin,Management"
            AZOPS_STRICT_MODE                  = @{ AzOpsStrictMode = 0 }
            AZOPS_SKIP_RESOURCE_GROUP          = @{ AzOpsSkipResourceGroup = 1 }
            AZOPS_SKIP_POLICY                  = @{ AzOpsSkipPolicy = 0 }
            AZOPS_SKIP_ROLE                    = @{ AzOpsSkipRole = 0 }
            # Azure DevOps
            AZDEVOPS_AUTO_MERGE                = @{ AzDevOpsAutoMerge = 1 }
            AZDEVOPS_EMAIL                     = @{ AzDevOpsEmail = $null }
            AZDEVOPS_USERNAME                  = @{ AzDevOpsUsername = $null }
            AZDEVOPS_PULL_REQUEST              = @{ AzDevOpsPullRequest = $null }
            AZDEVOPS_PULL_REQUEST_ID           = @{ AzDevOpsPullRequestId = $null }
            AZDEVOPS_HEAD_REF                  = @{ AzDevOpsHeadRef = $null }
            AZDEVOPS_BASE_REF                  = @{ AzDevOpsBaseRef = $null }
            AZDEVOPS_API_URL                   = @{ AzDevOpsApiUrl = $null }
            AZDEVOPS_PROJECT_ID                = @{ AzDevOpsProjectId = $null }
            AZDEVOPS_REPOSITORY                = @{ AzDevOpsRepository = $null }
            AZDEVOPS_TOKEN                     = @{ AzDevOpsToken = $null }
            # GitHub
            GITHUB_AUTO_MERGE                  = @{ GitHubAutoMerge = 1 } # Auto merge pull requests for pull workflow
            GITHUB_EMAIL                       = @{ GitHubEmail = $null }
            GITHUB_USERNAME                    = @{ GitHubUsername = $null }
            GITHUB_PULL_REQUEST                = @{ GitHubPullRequest = $null } # Pull Request title
            GITHUB_HEAD_REF                    = @{ GitHubHeadRef = $null }
            GITHUB_BASE_REF                    = @{ GitHubBaseRef = $null }
            GITHUB_API_URL                     = @{ GitHubApiUrl = $null } # Built-in env var
            GITHUB_REPOSITORY                  = @{ GitHubRepository = $null } # Built-in env var
            GITHUB_TOKEN                       = @{ GitHubToken = $null } # Built-in env var
            GITHUB_COMMENTS                    = @{ GitHubComments = $null } # Built-in env var
            # Source Control
            SCM_PLATFORM                       = @{ SCMPlatform = "GitHub" }
        }
        # Iterate through each variable and take appropriate action
        foreach ($AzOpsEnv in $AzOpsEnvVariables.Keys) {
            $EnvVar = "env:\$AzOpsEnv"
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Checking environment variable $AzOpsEnv"
            try {
                # Check if environment variables already exist with value
                $EnvVarValue = Get-ChildItem -Path $EnvVar -ErrorAction Stop | Select-Object -ExpandProperty Value
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                # If variable wasn't found, set default value from hash table
                $AzOpsEnvValue = $AzOpsEnvVariables["$AzOpsEnv"].Values
                if ($AzOpsEnvValue) {
                    Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Cannot find $EnvVar, setting value to $AzOpsEnvValue"
                    Set-Item -Path $EnvVar -Value $AzOpsEnvValue -Force
                }
                # Set variable for later use
                $EnvVarValue = $AzOpsEnvValue
            }
            finally {
                # Set global variables for script
                $GlobalVar = $AzOpsEnvVariables["$AzOpsEnv"].Keys
                Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Setting global variable $GlobalVar to $EnvVarValue"
                # Convert comma separated vars to array (since all env vars are strings)
                if ($EnvVarValue -match ',') {
                    $EnvVarValue = $EnvVarValue -split ','
                }
                # Handle string to integer conversions (since env variables are always strings)
                if ($EnvVarValue -match '^(0|-*[1-9]+[0-9]*)$' -and $EnvVarValue -isnot [int]) {
                    $EnvVarValue = $EnvVarValue -as [int]
                }
                Set-Variable -Name $GlobalVar -Scope Global -Value $EnvvarValue
            }
        }

        # Create AzOpsState folder if not exists
        if (-not (Test-Path -Path $global:AzOpsState)) {
            New-Item -path $global:AzOpsState -Force -Type directory | Out-Null
        }

        # Validate number of AAD Tenants that the principal has access to.
        if (0 -eq $AzOpsIgnoreContextCheck) {
            $AzContextTenants = @($AllAzContext.Tenant.Id | Sort-Object -Unique)
            if ($AzContextTenants.Count -gt 1) {
                Write-AzOpsLog -Level Error -Topic "Initialize-AzOpsGlobalVariables" -Message "Unsupported number of tenants in context: $($AzContextTenants.Count) TenantID(s)
                TenantID(s): $($AzContextTenants -join ',')
                Please reconnect with Connect-AzAccount using an account/service principal that only have access to one tenant"
                break
            }
        }
        # Ensure that registry value for long path support in windows has been set
        Test-AzOpsRuntime

    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsGlobalVariables" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Get all subscriptions and Management Groups if InvalidateCache is set to 1 or if the variables are not set
        if ($global:AzOpsInvalidateCache -eq 1 -or -not(Get-Variable -Scope Global -Name AzOpsAzManagementGroup -ValueOnly -ErrorAction SilentlyContinue) -or -not(Get-Variable -Scope Global -Name AzOpsSubscriptions -ValueOnly -ErrorAction SilentlyContinue)) {
            #Get current tenant id
            $TenantId = (Get-AzContext).Tenant.Id
            # Set root scope variable basd on tenantid to be able to validate tenant root access if partial discovery is not enabled
            $RootScope = '/providers/Microsoft.Management/managementGroups/{0}' -f $TenantId
            # Initialize global variable for subscriptions - get all subscriptions in Tenant
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Initializing Global Variable AzOpsSubscriptions"
            $global:AzOpsSubscriptions = Get-AzOpsAllSubscription -ExcludedOffers $global:AzOpsExcludedSubOffer -ExcludedStates $global:AzOpsExcludedSubState -TenantId $TenantId
            # Initialize global variable for Management Groups
            $global:AzOpsAzManagementGroup = @()
            # Initialize global variable for partial root discovery that will be set in AzOpsAllManagementGroup
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Global Variable AzOpsState or AzOpsAzManagementGroup is not Initialized. Initializing it now"
            # Get all managementgroups that principal has access to
            $global:AzOpsPartialRoot = @()

            $managementGroups = (Get-AzManagementGroup -ErrorAction:Stop)
            if ($RootScope -in ($managementGroups | Select-Object -Property Id).Id -or 1 -eq $global:AzOpsSupportPartialMgDiscovery) {
                # Handle user provided management groups
                if (1 -eq $global:AzOpsSupportPartialMgDiscovery -and $global:AzOpsPartialMgDiscoveryRoot -match '.') {
                    $ManagementGroups = @()
                    Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Processing user provided root management groups"
                    $global:AzOpsPartialMgDiscoveryRoot -split ',' | ForEach-Object -Process {
                        # Add for recursive discovery
                        $ManagementGroups += [pscustomobject]@{ Name = $_ }
                        # Add user provided root to partial root variable to know where discovery should start
                        $global:AzOpsPartialRoot += Get-AzManagementGroup -GroupId $_ -Recurse -Expand -WarningAction SilentlyContinue
                    }
                }
                Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Total Count of Management Group: $(($managementGroups | Measure-Object).Count)"
                foreach ($mgmtGroup in $managementGroups) {
                    Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Expanding Management Group : $($mgmtGroup.Name)"
                    $global:AzOpsAzManagementGroup += Get-AzOpsAllManagementGroup -ManagementGroup $mgmtGroup.Name
                }
                $global:AzOpsAzManagementGroup = $global:AzOpsAzManagementGroup | Sort-Object -Property Id -Unique

                Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Global Variable AzOpsState or AzOpsAzManagementGroup is initialized"

            }
            else {
                Write-AzOpsLog -Level Error -Topic "Initialize-AzOpsGlobalVariables" -Message "Cannot access root management group $RootScope. Verify that principal $((Get-AzContext).Account.Id) have access or set env:AZOPS_SUPPORT_PARTIAL_MG_DISCOVERY to 1 for partial discovery support"
            }

        }
        else {
            # If InvalidateCache was is not set to 1 and $global:AzOpsAzManagementGroup and $global:AzOpsSubscriptions set, use cached information
            Write-AzOpsLog -Level Verbose -Topic "Initialize-AzOpsGlobalVariables" -Message "Using cached values for AzOpsAzManagementGroup and AzOpsSubscriptions"
        }

    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Initialize-AzOpsGlobalVariables" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}
