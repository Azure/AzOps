#!/usr/bin/pwsh

Import-Module $PSScriptRoot/src/AzOps.psd1 -Force
. $PSScriptRoot/src/private/Start-AzOpsNativeExecution.ps1

function Logging {

    process {
        if ($env:INPUT_VERBOSE -eq "true") {
            $PSDefaultParameterValues['*-AzOps*:Verbose'] = $true
        }
        if ($env:INPUT_DEBUG -eq "true") {
            $PSDefaultParameterValues['*-AzOps*:Debug'] = $true
        }
    }

}

function Initialization {

    begin {
        try {
            # Create [pscredential]
            $credentials = ($env:INPUT_AZURE_CREDENTIALS | ConvertFrom-Json)
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $credentials.clientId, ($credentials.clientSecret | ConvertTo-SecureString -AsPlainText -Force)

            # Connect azure account
            Connect-AzAccount -TenantId $credentials.tenantId -ServicePrincipal -Credential $credential -SubscriptionId $credentials.subscriptionId -WarningAction SilentlyContinue | Out-Null
            # Configure git
            Start-AzOpsNativeExecution {
                git config --global user.email $env:INPUT_GITHUB_EMAIL
                git config --global user.name $env:INPUT_GITHUB_USERNAME
            } | Out-Host
        }
        catch {
            Write-Error -Message $PSItem.Exception.Message
            exit 1
        }
    }

    process {
        try {
            switch ($env:INPUT_MODE) {
                "Push" {
                    # Invoke push operation
                    Invoke-AzOpsGitPush
                }

                "Pull" {
                    # Invoke pull operation
                    Invoke-AzOpsGitPull
                }
            }
        }
        catch {
            Write-Error -Message $PSItem.Exception.Message
            exit 1
        }
    }

    end {
    }

}

Logging
Initialization