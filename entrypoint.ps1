#!/usr/bin/pwsh

Import-Module $PSScriptRoot/src/AzOps.psd1 -Force
. $PSScriptRoot/src/private/Start-AzOpsNativeExecution.ps1
. $PSScriptRoot/src/private/Write-AzOpsLog.ps1

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

            if($env:INPUT_AZOPS_STATE)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsState to $($env:INPUT_AZOPS_STATE)"
                $env:AzOpsState = $env:INPUT_AZOPS_STATE
            }
            if($env:INPUT_AZOPS_ENROLLMENT_ACCOUNT_PRINCIPAL_NAME)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsEnrollmentAccountPrincipalName to $($env:INPUT_AZOPS_ENROLLMENT_ACCOUNT_PRINCIPAL_NAME)"
                $env:AzOpsEnrollmentAccountPrincipalName = $env:INPUT_AZOPS_STATE
            }
            if($env:INPUT_AZOPS_OFFER_TYPE)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting offerType to $($env:INPUT_AZOPS_OFFER_TYPE)"
                $env:offerType = $env:INPUT_AZOPS_OFFER_TYPE
            }
            if($env:INPUT_AZOPS_DEFAULT_DEPLOYMENT_REGION)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsDefaultDeploymentRegion to $($env:INPUT_AZOPS_DEFAULT_DEPLOYMENT_REGION)"
                $env:AzOpsDefaultDeploymentRegion = $env:INPUT_AZOPS_DEFAULT_DEPLOYMENT_REGION
            }
            if($env:INPUT_AZOPS_INVALIDATE_CACHE)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting InvalidateCache to $($env:INPUT_AZOPS_INVALIDATE_CACHE)"
                $env:InvalidateCache = $env:INPUT_AZOPS_INVALIDATE_CACHE
            }
            if($env:INPUT_AZOPS_IGNORE_CONTEXT_CHECK)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting IgnoreContextCheck to $($env:INPUT_AZOPS_IGNORE_CONTEXT_CHECK)"
                $env:IgnoreContextCheck = $env:INPUT_AZOPS_IGNORE_CONTEXT_CHECK
            }
            if($env:INPUT_AZOPS_THROTTLE_LIMIT)
            {
                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Setting AzOpsThrottleLimit to $($env:INPUT_AZOPS_THROTTLE_LIMIT)"
                $env:AzOpsThrottleLimit = $env:INPUT_AZOPS_THROTTLE_LIMIT
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
            Write-AzOpsLog -Level Error -Topic "git" -Message $PSItem.Exception.Message
            exit 1
        }
    }

    end {
    }

}

Logging
Initialization
