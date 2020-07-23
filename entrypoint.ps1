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
            Start-AzOpsNativeExecution {
                git config --global user.email $env:GITHUB_EMAIL
                git config --global user.name $env:GITHUB_USERNAME
            } | Out-Host

            # Print environment variables
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_STATE is $($env:AZOPS_STATE)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_ENROLLMENT_ACCOUNT is $($env:AZOPS_ENROLLMENT_ACCOUNT)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_OFFER_TYPE is $($env:AZOPS_OFFER_TYPE)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_DEFAULT_DEPLOYMENT_REGION is $($env:AZOPS_DEFAULT_DEPLOYMENT_REGION)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_INVALIDATE_CACHE is $($env:AZOPS_INVALIDATE_CACHE)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_IGNORE_CONTEXT_CHECK is $($env:AZOPS_IGNORE_CONTEXT_CHECK)"
            Write-AzOpsLog -Level Information -Topic "entrypoint" -Message "AZOPS_THROTTLE_LIMIT is $($env:AZOPS_THROTTLE_LIMIT)"

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
