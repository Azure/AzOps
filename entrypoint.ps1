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

            # Set environment variables
            if ($env:AZOPS_STATE) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsState to $($env:AZOPS_STATE)"
                $env:AzOpsState = $env:AZOPS_STATE
            }
            if ($env:AZOPS_ENROLLMENT_ACCOUNT) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsEnrollmentAccountPrincipalName to $($env:AZOPS_ENROLLMENT_ACCOUNT)"
                $env:AzOpsEnrollmentAccountPrincipalName = $env:AZOPS_ENROLLMENT_ACCOUNT
            }
            if ($env:AZOPS_OFFER_TYPE) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting offerType to $($env:AZOPS_OFFER_TYPE)"
                $env:AzOpsOfferType = $env:AZOPS_OFFER_TYPE
            }
            if ($env:AZOPS_DEFAULT_DEPLOYMENT_REGION) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsDefaultDeploymentRegion to $($env:AZOPS_DEFAULT_DEPLOYMENT_REGION)"
                $env:AzOpsDefaultDeploymentRegion = $env:AZOPS_DEFAULT_DEPLOYMENT_REGION
            }
            if ($env:AZOPS_INVALIDATE_CACHE) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting InvalidateCache to $($env:AZOPS_INVALIDATE_CACHE)"
                $env:InvalidateCache = $env:AZOPS_INVALIDATE_CACHE
            }
            if ($env:AZOPS_IGNORE_CONTEXT_CHECK) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting IgnoreContextCheck to $($env:AZOPS_IGNORE_CONTEXT_CHECK)"
                $env:IgnoreContextCheck = $env:AZOPS_IGNORE_CONTEXT_CHECK
            }
            if ($env:AZOPS_THROTTLE_LIMIT) {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsThrottleLimit to $($env:AZOPS_THROTTLE_LIMIT)"
                $env:AzOpsThrottleLimit = $env:AZOPS_THROTTLE_LIMIT
            }
        }
        catch {
            Write-AzOpsLog -Level Error -Topic "pwsh" -Message $PSItem.Exception.Message
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
            Write-AzOpsLog -Level Error -Topic "pwsh" -Message $PSItem.Exception.Message
            exit 1
        }
    }

    end {
    }

}

Logging
Initialization
