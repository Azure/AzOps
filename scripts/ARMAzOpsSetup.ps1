<#
    .SYNOPSIS
        PowerShell script to bootstrap AzOps into GitHub as part of the Enterprise-Scale landing zone portal deployment experience.
        It is designed to run in deploymentScripts invoked from the ESLZ portal experience.
    .PARAMETER KeyVault
        Name of the Key Vault that stores PAT and SPN secrets
    .PARAMETER GitHubUserNameOrOrg
        Github Username or Organization, for example Azure
    .PARAMETER PATSecretName
        Name of Key Vault secret where personal access token is stored
    .PARAMETER SPNSecretName
        Name of Key Vault secret where Service Principal Secret is stored
    .PARAMETER SPNAppId
        ApplicationId of the Service Principal to be used
    .PARAMETER AzureTenantId
        Azure Tenant Id to be used
    .PARAMETER AzureSubscriptionId
        Azure Subscription Id to be used
    .PARAMETER EnterpriseScalePrefix
        Prefix of the Enterprise Scale deployment
    .PARAMETER NewRepositoryName
        Name of the repository to be created
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$KeyVault,
    [Parameter(Mandatory = $true)][string]$GitHubUserNameOrOrg,
    [Parameter(Mandatory = $true)][string]$PATSecretName,
    [Parameter(Mandatory = $true)][string]$SPNSecretName,
    [Parameter(Mandatory = $true)][string]$SpnAppId,
    [Parameter(Mandatory = $true)][string]$AzureTenantId,
    [Parameter(Mandatory = $true)][string]$AzureSubscriptionId,
    [Parameter(Mandatory = $true)][string]$EnterpriseScalePrefix,
    [Parameter(Mandatory = $true)][string]$NewRepositoryName
)
begin {
    $DeploymentScriptOutputs = @{}

    $ESLZGitHubOrg = "Azure"
    $ESLZRepository = "AzOps-Accelerator"
    $NewESLZRepository = $NewRepositoryName
    $DeploymentScriptOutputs['New Repository'] = $NewRepositoryName

    Write-Host "The request has been accepted for processing, but the processing has not been completed."

    # Adding sleep so that RBAC can propegate
    Start-Sleep -Seconds 500

    # Install dependencies
    $ErrorActionPreference = "Continue"
    Install-Module -Name PowerShellForGitHub, PSSodium -Confirm:$false -Force
    Import-Module -Name PowerShellForGitHub, PSSodium
    Set-GitHubConfiguration -DisableTelemetry

    function Invoke-GHRequest {
        param (
            [Parameter(Mandatory = $true)]$PatSecret,
            [Parameter(Mandatory = $false)]$Path,
            [Parameter(Mandatory = $false)]$RequestBody,
            [Parameter(Mandatory = $true)][ValidateSet("Get", "Put", "Post")]$Method,
            [Parameter(Mandatory = $true)]$Org,
            [Parameter(Mandatory = $true)]$Repo
        )
        begin {
            $RequestUri = 'https://api.github.com/repos/{0}/{1}' -f $Org, $Repo
            if ($Path) { $RequestUri = "$($RequestUri)$($Path)" }
            $Request = @{
                Method  = $Method
                Headers = @{
                    Authorization  = "Token $($PATSecret)"
                    'Content-Type' = "application/json"
                    Accept         = "application/vnd.github.v3+json"
                }
                Uri     = $RequestUri
            }
            if ($RequestBody) {
                $Request.Body = $RequestBody
            }
        } process {
            try {
                Write-Verbose -Message "Calling $RequestUri"
                Invoke-RestMethod @Request -ErrorAction Stop
            }
            catch {
                throw $_
            }
        }
    }
}
process {
    #region Get secrets from Key Vault
    try {
        Write-Host "Getting secrets from KeyVault"
        $PATSecret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $PATSecretName -AsPlainText
        $SPNSecret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $SPNSecretName -AsPlainText
    }
    catch {
        throw "Failed to retrieve the secret from $($KeyVault).`r`n$_"
    }
    #endregion Get secrets from Key Vault

    # Create base call with uri
    $BaseGHRest = @{
        PatSecret = $PATSecret
        Org       = $GitHubUserNameOrOrg
        Repo      = $NewRepositoryName
    }

    #region authenticate to GitHub pwsh module using PAT
    try {
        $ghCred = New-Object System.Management.Automation.PSCredential "ignore", ($PATSecret | ConvertTo-SecureString -AsPlainText -Force)
        Write-Host "Authenticating to GitHub using PA token..."
        Set-GitHubAuthentication -Credential $ghCred
    }
    catch {
        throw "Failed to authenticate to Git. Ensure you provided the correct PA Token for $($GitHubUserNameOrOrg).`r`n$_"
    }
    #endregion authenticate to GitHub pwsh module using PAT

    #region Check if target GitHub Repository exists
    Write-Host "Checking if repository $NewRepositoryName already exists before continuing..."
    $RepoExists = Invoke-GHRequest -Method Get @BaseGHRest -ErrorAction SilentlyContinue

    if ([string]::IsNullOrEmpty($RepoExists)) {
        try {
            Write-Host "Moving on; creating the repository :-)"
            Get-GitHubRepository -OwnerName $ESLZGitHubOrg `
                -RepositoryName $ESLZRepository | New-GitHubRepositoryFromTemplate `
                -TargetRepositoryName $NewESLZRepository `
                -TargetOwnerName $GitHubUserNameOrOrg `
                -Private
        }
        catch {
            throw "Failed to create repository`r`n$_"
        }
        # Creating secrets for the Service Principal into GitHub
    }
    else {
        throw "Repository $($GitHubUserNameOrOrg)/$($NewESLZRepository) already exists"
    }

    #region Get GitHub public key and create new secrets
    try {
        Write-host "Getting GitHub Public Key to create new secrets..."
        $GitHubPublicKey = Invoke-GHRequest @BaseGHRest -Path "/actions/secrets/public-key" -Method Get

        #Convert secrets to sodium with public key
        $Secrets = @{
            ARM_CLIENT_ID       = (ConvertTo-SodiumEncryptedString -Text $SpnAppId -PublicKey $GitHubPublicKey.key)
            ARM_CLIENT_SECRET   = (ConvertTo-SodiumEncryptedString -Text $SPNSecret -PublicKey $GitHubPublicKey.key)
            ARM_TENANT_ID       = (ConvertTo-SodiumEncryptedString -Text $AzureTenantId -PublicKey $GitHubPublicKey.key)
            ARM_SUBSCRIPTION_ID = (ConvertTo-SodiumEncryptedString -Text $AzureSubscriptionId -PublicKey $GitHubPublicKey.key)
        }

        # Create secrets
        foreach ($Secret in $Secrets.Keys) {
            Write-Host "Creating secret $secret"
            $SecretBody = @{
                encrypted_value = $Secrets[$Secret]
                key_id          = $GitHubPublicKey.Key_id
            } | ConvertTo-Json
            Invoke-GHRequest @BaseGHRest -Path "/actions/secrets/$secret" -RequestBody $SecretBody -Method Put
        }
    }
    catch {
        throw "Failed to create secrets $($GitHubUserNameOrOrg).`r`n$_"
    }
    #endregion Get GitHub public key and create new secrets

    #region Trigger repository dispatch for AzOps-Pull job
    try {
        Write-Host "Invoking GitHub Action to bootstrap the repository."
        $DispatchBody = @{
            event_type = 'Enterprise-Scale Deployment'
        } | ConvertTo-Json
        Invoke-GHRequest @BaseGHRest -Method Post -RequestBody $DispatchBody -Path '/dispatches'

    }
    catch {
        throw "Failed to trigger repository dispatch $($GitHubUserNameOrOrg)/$($NewESLZRepository)`r`n$_"
    }
    #endregion Trigger repository dispatch for AzOps-Pull job
}
