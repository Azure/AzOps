#!/usr/bin/pwsh

Import-Module $PSScriptRoot/src/AzOps.psd1 -Force
. $PSScriptRoot/src/private/Start-AzOpsNativeExecution.ps1
. $PSScriptRoot/src/private/Write-AzOpsLog.ps1

function Logging {

    process {
        if ($env:VERBOSE -eq "1") {
            $PSDefaultParameterValues['*-AzOps*:Verbose'] = $true
        }
        if ($env:DEBUG -eq "1") {
            $PSDefaultParameterValues['*-AzOps*:Debug'] = $true
        }
    }

}

function Initialization {

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    param ()

    begin {
        try {
            # Create credential
            $credentials = ($env:AZURE_CREDENTIALS | ConvertFrom-Json)
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $credentials.clientId, ($credentials.clientSecret | ConvertTo-SecureString -AsPlainText -Force)

            # Connect azure account
            Connect-AzAccount -TenantId $credentials.tenantId -ServicePrincipal -Credential $credential -SubscriptionId $credentials.subscriptionId -WarningAction SilentlyContinue | Out-Null

            # Configure git
            switch ($env:SCM_PLATFORM) {
                "AzureDevOps" {
                    Start-AzOpsNativeExecution {
                        git config --global user.name $env:AZDEVOPS_USERNAME
                        git config --global user.email $env:AZDEVOPS_EMAIL
                    } | Out-Host
                }
                default {
                    Start-AzOpsNativeExecution {
                        git config --global user.name $env:GITHUB_USERNAME
                        git config --global user.email $env:GITHUB_EMAIL
                    } | Out-Host
                }
            }

            # Update branch names
            if (($env:SCM_PLATFORM -eq "AzureDevOps") -and ($env:INPUT_MODE -eq "Push")) {
                $env:AZDEVOPS_HEAD_REF = ($env:AZDEVOPS_HEAD_REF).Replace("refs/heads/", "")
                $env:AZDEVOPS_BASE_REF = ($env:AZDEVOPS_BASE_REF).Replace("refs/heads/", "")
            }

            # Print environment variables
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_MODE: $($env:INPUT_MODE)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_STATE: $($env:AZOPS_STATE)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_ENROLLMENT_ACCOUNT: $($env:AZOPS_ENROLLMENT_ACCOUNT)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_OFFER_TYPE: $($env:AZOPS_OFFER_TYPE)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_DEFAULT_DEPLOYMENT_REGION: $($env:AZOPS_DEFAULT_DEPLOYMENT_REGION)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_INVALIDATE_CACHE: $($env:AZOPS_INVALIDATE_CACHE)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_IGNORE_CONTEXT_CHECK: $($env:AZOPS_IGNORE_CONTEXT_CHECK)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_THROTTLE_LIMIT: $($env:AZOPS_THROTTLE_LIMIT)"
            Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZOPS_STRICT_MODE: $($env:AZOPS_STRICT_MODE)"
            switch ($env:SCM_PLATFORM) {
                "AzureDevOps" {
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZDEVOPS_AUTO_MERGE: $($env:AZDEVOPS_AUTO_MERGE)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZDEVOPS_EMAIL: $($env:AZDEVOPS_EMAIL)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZDEVOPS_USERNAME: $($env:AZDEVOPS_USERNAME)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "AZDEVOPS_PULL_REQUEST: $($env:AZDEVOPS_PULL_REQUEST)"
                }
                default {
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_AUTO_MERGE: $($env:GITHUB_AUTO_MERGE)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_EMAIL: $($env:GITHUB_EMAIL)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_USERNAME: $($env:GITHUB_USERNAME)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_PULL_REQUEST: $($env:GITHUB_PULL_REQUEST)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_HEAD_REF: $($env:GITHUB_HEAD_REF)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_BASE_REF: $($env:GITHUB_BASE_REF)"
                    Write-AzOpsLog -Level Information -Topic "env-var" -Message "GITHUB_COMMENTS: $($env:GITHUB_COMMENTS)"
                }
            }

            # Initialize global variables
            Initialize-AzOpsGlobalVariables
        }
        catch {
            Write-AzOpsLog -Level Error -Topic "entrypoint" -Message $PSItem.Exception.Message
            exit 1
        }
    }

    process {
        try {
            switch ($env:INPUT_MODE) {
                "Push" {
                    Invoke-AzOpsGitPush
                }
                "Pull" {
                    Invoke-AzOpsGitPull
                }
            }
        }
        catch {
            Write-AzOpsLog -Level Error -Topic "entrypoint" -Message $PSItem.Exception.Message
            exit 1
        }
    }

    end {
    }

}

Logging
Initialization
