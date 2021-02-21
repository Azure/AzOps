function New-AzOpsStateDeployment {

    [Alias('New-AzOpsStateDeployment')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript({ Test-Path $_ })]
        $FileName,

        [string]
        $StatePath
    )

    begin {
        $subscriptions = Get-AzSubscription
        $enrollmentAccounts = Get-AzEnrollmentAccount
    }

    process {
        Write-PSFMessage -String 'New-AzOpsStateDeployment.Processing' -StringValues $FileName
        $scopeObject = New-AzOpsScope -Path (Get-Item -Path $FileName).FullName -StatePath $StatePath

        if (-not $scopeObject.Type) {
            Write-PSFMessage -Level Warning -String 'New-AzOpsStateDeployment.InvalidScope' -StringValues $FileName -Target $scopeObject
            return
        }
        #TODO: Clarify whether this exclusion was intentional
        if ($scopeObject.Type -ne 'subscriptions') { return }

        #region Process Subscriptions
        if ($FileName -match '/*.subscription.json$') {
            Write-PSFMessage -String 'New-AzOpsStateDeployment.Subscription' -StringValues $FileName -Target $scopeObject
            $subscription = $subscriptions | Where-Object Name -EQ $scopeObject.subscriptionDisplayName

            #region Subscription needs to be created
            if (-not $subscription) {
                Write-PSFMessage -String 'New-AzOpsStateDeployment.Subscription.New' -StringValues $FileName -Target $scopeObject

                if (-not $enrollmentAccounts) {
                    Write-PSFMessage -Level Error -String 'New-AzOpsStateDeployment.NoEnrollmentAccount' -Target $scopeObject
                    Write-PSFMessage -Level Error -String 'New-AzOpsStateDeployment.NoEnrollmentAccount.Solution' -Target $scopeObject
                    return
                }

                if ($cfgEnrollmentAccount = Get-PSFConfigValue -FullName 'AzOps.General.EnrollmentAccountPrincipalName') {
                    Write-PSFMessage -String 'New-AzOpsStateDeployment.EnrollmentAccount.Selected' -StringValues $cfgEnrollmentAccount
                    $enrollmentAccountObjectId = ($enrollmentAccounts | Where-Object PrincipalName -eq $cfgEnrollmentAccount).ObjectId
                }
                else {
                    Write-PSFMessage -String 'New-AzOpsStateDeployment.EnrollmentAccount.First' -StringValues @($enrollmentAccounts)[0].PrincipalName
                    $enrollmentAccountObjectId = @($enrollmentAccounts)[0].ObjectId
                }

                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsStateDeployment.Subscription.Creating' -ActionStringValues $scopeObject.Name -ScriptBlock {
                    $subscription = New-AzSubscription -Name $scopeObject.Name -OfferType (Get-PSFConfigValue -FullName 'AzOps.General.OfferType') -EnrollmentAccountObjectId $enrollmentAccountObjectId -ErrorAction Stop
                    $subscriptions = @($subscriptions) + @($subscription)
                } -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet

                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsStateDeployment.Subscription.AssignManagementGroup' -ActionStringValues $subscription.Name, $scopeObject.ManagementGroupDisplayName -ScriptBlock {
                    New-AzManagementGroupSubscription -GroupName $scopeObject.ManagementGroup -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop
                } -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
            }
            #endregion Subscription needs to be created
            #region Subscription exists already
            else {
                Write-PSFMessage -String 'New-AzOpsStateDeployment.Subscription.Exists' -StringValues $subscription.Name, $subscription.Id -Target $scopeObject
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