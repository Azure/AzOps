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

# Install the required versions of Powershell Modules used for testing
Install-Module -Name "Az.Accounts" -RequiredVersion $env:AZ_ACCOUNTS_REQUIREDVERSION -Force
Install-Module -Name "Az.Resources" -RequiredVersion $env:AZ_RESOURCES_REQUIREDVERSION -Force
Install-Module -Name "Pester" -RequiredVersion $env:PESTER_REQUIREDVERSION -Force

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
