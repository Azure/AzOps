<#
.SYNOPSIS
    Initializes the environment and global variables variables required for the AzOps cmdlets.
.DESCRIPTION
    Initializes the environment and global variables variables required for the AzOps cmdlets.
    Key / Values in the AzOpsEnvVariables hashtable will be set as environment variables and global variables.
    All Management Groups and Subscription that the user/service principal have access to will be discovered and added to their respective variables.
.EXAMPLE
    Initialize-AzOpsGlobalVariables -Verbose
.INPUTS
    None
.OUTPUTS
    - Global variables and environment variables as defined in @{ $AzOpsEnvVariables }
    - $Global:AzOpsAzManagementGroup as well as $Global:AzOpsSubscriptions with all subscriptions and Management Groups that was discovered
#>
function Initialize-AzOpsGlobalVariables {
    
    [CmdletBinding()]
    [OutputType()]
    param (
    )

    begin {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")

        # Validate that Azure Context is available
        $AllAzContext = Get-AzContext -ListAvailable
        if (-not($AllAzContext)) {
            Write-AzOpsLog -Level Error -Topic "pwsh" -Message "No context available in Az PowerShell. Please use Connect-AzAccount and connect before using the command"
            break
        }

        # Required environment variables hashtable with default values
        $AzOpsEnvVariables = @{
            AzOpsState                          = (Join-Path $pwd -ChildPath "azops") # Folder to store AzOpsState artefact
            AzOpsMainTemplate                   = "$PSScriptRoot\..\..\template\template.json" # Main template json
            AzOpsStateConfig                    = "$PSScriptRoot\..\AzOpsStateConfig.json" # Configuration file for resource serialization
            AzOpsEnrollmentAccountPrincipalName = $null
            AzOpsOfferType                      = 'MS-AZR-0017P'
            AzOpsDefaultDeploymentRegion        = 'northeurope' # Default deployment region for state deployments (ARM region, not region where a resource is deployed)
            InvalidateCache                     = 1 # Invalidates cache and ensures that Management Groups and Subscriptions are re-discovered
            IgnoreContextCheck                  = 0 # If set to 1, skip AAD tenant validation == 1
            AzOpsThrottleLimit                  = 10 # Throttlelimit used in Foreach-Object -Parallel for resource/subscription discovery
        }
        # Iterate through each variable and take appropriate action
        foreach ($AzOpsEnv in $AzOpsEnvVariables.Keys) {
            $EnvVar = "env:\$AzOpsEnv"
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Checking environment variable $AzOpsEnv"
            try {
                # Check if environment variables already exist with value
                $EnvVarValue = Get-ChildItem -Path $EnvVar -ErrorAction Stop | Select-Object -ExpandProperty Value
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                # If variable wasn't found, set default value from hash table
                $AzOpsEnvValue = $AzOpsEnvVariables["$AzOpsEnv"]
                if ($AzOpsEnvValue) {
                    Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Cannot find $EnvVar, setting value to $AzOpsEnvValue"
                    Set-Item -Path $EnvVar -Value $AzOpsEnvValue -Force
                }
                # Set variable for later use
                $EnvVarValue = $AzOpsEnvValue
            }
            finally {
                # Set global variables for script
                Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Setting global variable $AzOpsEnv to $EnvVarValue"
                Set-Variable -Name $AzOpsEnv -Scope Global -Value $EnvvarValue
            }
        }

        # Create AzOpsState folder if not exists
        if (-not (Test-Path -Path $env:AzOpsState)) {
            New-Item -path $env:AzOpsState -Force -Type directory | Out-Null
        }

        # Validate number of AAD Tenants that the principal has access to.
        if (0 -eq $IgnoreContextCheck) {
            $AzContextTenants = @($AllAzContext.Tenant.Id | Sort-Object -Unique)
            if ($AzContextTenants.Count -gt 1) {
                Write-AzOpsLog -Level Error -Topic "pwsh" -Message "Unsupported number of tenants in context: $($AzContextTenants.Count) TenantID(s)
                TenantID(s): $($AzContextTenants -join ',')
                Please reconnect with Connect-AzAccount using an account/service principal that only have access to one tenant"
                break
            }
        }

    }

    process {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Get all subscriptions and Management Groups if InvalidateCache is set to 1 or if the variables are not set
        if ($Global:invalidateCache -eq 1 -or $global:AzOpsAzManagementGroup.count -eq 0 -or $global:AzOpsSubscriptions.Count -eq 0) {

            # Initialize global variable for subscriptions - get all subscriptions in Tenant
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Global Variable AzOpsSubscriptions not initialized. Initializing it now $(get-Date)"
            $global:AzOpsSubscriptions = Get-AzSubscription -TenantId (Get-AzContext).Tenant.Id
            # Initialize global variable for Management Groups
            $global:AzOpsAzManagementGroup = @()

            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Global Variable AzOpsState or AzOpsAzManagementGroup is not Initialized. Initializing it now $(get-Date)"
            # Get all managementgroups that principal has access to
            try {
                $managementGroups = (Get-AzManagementGroup -ErrorAction:Stop)
                if ($managementGroups) {
                    Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Total Count of Management Group: $(($managementGroups | Measure-Object).Count)"
                    foreach ($mgmtGroup in $managementGroups) {
                        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Expanding Management Group : $($mgmtGroup.Name)"
                        $global:AzOpsAzManagementGroup += (Get-AzManagementGroup -GroupName $mgmtGroup.Name -Expand -Recurse)
                    }
                    Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Global Variable AzOpsState or AzOpsAzManagementGroup is initialized  $(Get-Date)"
                }
            }
            catch {
                # Handle errors related to Get-AzManagementGroup
                Write-AzOpsLog -Level Error -Topic "pwsh" -Message "Cannot find any Management Groups. Does the Service Principal/User have the appropriate privileges on the root Management Group or is the Management Group hierarchy not yet created?"
                Write-AzOpsLog -Level Error -Topic "pwsh" -Message $_
                throw
            }
        }
        else {
            # If InvalidateCache was is not set to 1 and $global:AzOpsAzManagementGroup and $global:AzOpsSubscriptions set, use cached information
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Using Cached AzOpsAzManagementGroup and AzOpsSubscriptions"
        }

        # Test if Management Groups or subscriptions with duplicate names exist and throw error if not
        $DuplicateMgOrSubName = Test-AzOpsDuplicateSubMgmtGroup
        if ($DuplicateMgOrSubName) {
            $DuplicateMgOrSubName | ForEach-Object -Process {
                Write-AzOpsLog -Level Warning -Topic "pwsh" -Message "$($_.Count) $($_.Type)s exists with displayname '$($_.DuplicateName)'`r`n - $($_.Ids -join ',')"
            }
            Write-AzOpsLog -Level Error -Topic "pwsh" -Message "Ensure all subscriptions and Management Groups have unique displaynames and try again"
            break
        }
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}
