<#
.SYNOPSIS
    Initializes the build environment used for testing the AzOps Module in Azure Pipelines.
.DESCRIPTION
    Initializes the build environment used for testing the AzOps Module in Azure Pipelines.
    This script should be run on the "ubuntu-latest" build agent to ensure the environment is correctly configured before running any tests.
.EXAMPLE
    Initialize-AzOpsTestEnvironment
.INPUTS
    None
.OUTPUTS
    None
#>

# Output a the PSVersionTable to simplify version troubleshooting
$PSVersionTable

# Install the required versions of Powershell Modules used for testing if not installed
$requiredModules = @(
    @{
        Name            = "Az.Accounts"
        Repository      = "PSGallery"
        RequiredVersion = $($requiredVersion = $env:AZ_ACCOUNTS_REQUIREDVERSION ?? "latest"; $requiredVersion)
    },
    @{
        Name            = "Az.Resources"
        Repository      = "PSGallery"
        RequiredVersion = $($requiredVersion = $env:AZ_RESOURCES_REQUIREDVERSION ?? "latest"; $requiredVersion)
    },
    @{
        Name            = "Pester"
        Repository      = "PSGallery"
        RequiredVersion = $($requiredVersion = $env:PESTER_REQUIREDVERSION ?? "latest"; $requiredVersion)
    },
    @{
        Name            = "PSScriptAnalyzer"
        Repository      = "PSGallery"
        RequiredVersion = $($requiredVersion = $env:PSSCRIPTANALYZER_REQUIREDVERSION ?? "latest"; $requiredVersion)
    }
)

$requiredModules | ForEach-Object {
    # Update RequiredVersion value if "latest" required
    if ($_.RequiredVersion -eq "latest") {
        $_.RequiredVersion = (Find-Module -Name $_.Name -Repository $_.Repository).Version
        Write-Verbose "Required module version: $($_.Name) ($($_.RequiredVersion)) (latest)"
    }
    else {
        Write-Verbose "Required module version: $($_.Name) ($($_.RequiredVersion))"
    }
    # Check to see if required module version is installed and install if not
    $lookupModule = Get-Module -Name $_.Name -ListAvailable
    $lookupModuleAgainstVersion = $lookupModule | Where-Object Version -EQ $_.RequiredVersion
    if ($lookupModule -and (-not ($lookupModuleAgainstVersion))) {
        Write-Verbose -Message "Updating module $($_.Name) ($($_.RequiredVersion))"
        Update-Module -Name $_.Name -RequiredVersion $_.RequiredVersion -Force
    }
    elseif (-not ($lookupModule)) {
        Write-Verbose -Message "Installing module $($_.Name) ($($_.RequiredVersion))"
        Install-Module -Name $_.Name -Repository $_.Repository -RequiredVersion $_.RequiredVersion -Force
    }
    else {
        Write-Verbose -Message "Found module $($_.Name) ($($lookupModule.Version -join ', '))"
    }
}

# Output a list of available PowerShell Modules installed on the build agent
Get-Module -ListAvailable

# Create credential variables
$azureCredentials = $env:AZURE_CREDENTIALS | ConvertFrom-Json
$credential = New-Object System.Management.Automation.PSCredential `
    -ArgumentList `
$($azureCredentials.clientId), `
$($azureCredentials.clientSecret | ConvertTo-SecureString -AsPlainText -Force)

Connect-AzAccount `
    -ServicePrincipal `
    -TenantId $($azureCredentials.tenantId) `
    -SubscriptionId $($azureCredentials.subscriptionId) `
    -Credential $credential
