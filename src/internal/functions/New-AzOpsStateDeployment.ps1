function New-AzOpsStateDeployment {

    <#
        .SYNOPSIS
            Deploys a set of ARM templates into Azure.
        .DESCRIPTION
            Deploys a set of ARM templates into Azure.
            Define the state using Invoke-AzOpsPull and maintain it via:
            - Invoke-AzOpsGitPull
            - Invoke-AzOpsGitPush
        .PARAMETER FileName
            Root path from which to deploy.
        .PARAMETER StatePath
            The overall path of the state to deploy.
        .EXAMPLE
            > New-StateDeployment -FileName $fileName -StatePath $StatePath
            Deploys the specified set of ARM templates into Azure.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path $_ })]
        $FileName,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    begin {
        $subscriptions = Get-AzSubscription
        $enrollmentAccounts = Get-AzEnrollmentAccount
    }

    process {
        Write-AzOpsMessage -LogLevel Important -LogString 'New-AzOpsStateDeployment.Processing' -LogStringValues $FileName
        $scopeObject = New-AzOpsScope -Path (Get-Item -Path $FileName).FullName -StatePath $StatePath

        if (-not $scopeObject.Type) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'New-AzOpsStateDeployment.InvalidScope' -LogStringValues $FileName -Target $scopeObject
            return
        }
        #TODO: Clarify whether this exclusion was intentional
        if ($scopeObject.Type -ne 'subscriptions') { return }

        #region Process Subscriptions
        if ($FileName -match '/*.subscription.json$') {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsStateDeployment.Subscription' -LogStringValues $FileName -Target $scopeObject
            $subscription = $subscriptions | Where-Object Name -EQ $scopeObject.subscriptionDisplayName

            #region Subscription needs to be created
            if (-not $subscription) {
                Write-AzOpsMessage -LogLevel Important -LogString 'New-AzOpsStateDeployment.Subscription.New' -LogStringValues $FileName -Target $scopeObject

                if (-not $enrollmentAccounts) {
                    Write-AzOpsMessage -LogLevel Error -LogString 'New-AzOpsStateDeployment.NoEnrollmentAccount' -Target $scopeObject
                    Write-AzOpsMessage -LogLevel Error -LogString 'New-AzOpsStateDeployment.NoEnrollmentAccount.Solution' -Target $scopeObject
                    return
                }

                if ($cfgEnrollmentAccount = Get-PSFConfigValue -FullName 'AzOps.Core.EnrollmentAccountPrincipalName') {
                    Write-AzOpsMessage -LogLevel Important -LogString 'New-AzOpsStateDeployment.EnrollmentAccount.Selected' -LogStringValues $cfgEnrollmentAccount
                    $enrollmentAccountObjectId = ($enrollmentAccounts | Where-Object PrincipalName -eq $cfgEnrollmentAccount).ObjectId
                }
                else {
                    Write-AzOpsMessage -LogLevel Important -LogString 'New-AzOpsStateDeployment.EnrollmentAccount.First' -LogStringValues @($enrollmentAccounts)[0].PrincipalName
                    $enrollmentAccountObjectId = @($enrollmentAccounts)[0].ObjectId
                }

                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsStateDeployment.Subscription.Creating' -ActionStringValues $scopeObject.Name -ScriptBlock {
                    $subscription = New-AzSubscription -Name $scopeObject.Name -OfferType (Get-PSFConfigValue -FullName 'AzOps.Core.OfferType') -EnrollmentAccountObjectId $enrollmentAccountObjectId -ErrorAction Stop
                    $subscriptions = @($subscriptions) + @($subscription)
                } -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet

                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsStateDeployment.Subscription.AssignManagementGroup' -ActionStringValues $subscription.Name, $scopeObject.ManagementGroupDisplayName -ScriptBlock {
                    New-AzManagementGroupSubscription -GroupName $scopeObject.ManagementGroup -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop
                } -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
            }
            #endregion Subscription needs to be created
            #region Subscription exists already
            else {
                Write-AzOpsMessage -LogLevel Verbose -LogString 'New-AzOpsStateDeployment.Subscription.Exists' -LogStringValues $subscription.Name, $subscription.Id -Target $scopeObject
                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsStateDeployment.Subscription.AssignManagementGroup' -ActionStringValues $subscription.Name, $scopeObject.ManagementGroupDisplayName -ScriptBlock {
                    New-AzManagementGroupSubscription -GroupName $scopeObject.ManagementGroup -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop
                } -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
            }
            #endregion Subscription exists already
        }
        if ($FileName -match '/*.providerfeatures.json$') {
            Register-AzOpsProviderFeature -FileName $FileName -ScopeObject $scopeObject
        }
        if ($FileName -match '/*.resourceproviders.json$') {
            Register-AzOpsResourceProvider -FileName $FileName -ScopeObject $scopeObject
        }
        #endregion Process Subscriptions
    }

}