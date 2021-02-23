function New-StateDeployment {
<#
	.SYNOPSIS
		Deploys a set of ARM templates into Azure.
	
	.DESCRIPTION
		Deploys a set of ARM templates into Azure.
		Define the state using Initialize-AzOpsRepository and maintain it via:
		- Invoke-AzOpsGitPull
		- Invoke-AzOpsGitPush
	
	.PARAMETER FileName
		Root path from which to deploy.
	
	.PARAMETER StatePath
		The overall path of the state to deploy.
	
	.EXAMPLE
		PS C:\> New-StateDeployment -FileName $fileName -StatePath $StatePath
	
		Deploys the specified set of ARM templates into Azure.
#>
	[Alias('New-AzOpsStateDeployment')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[ValidateScript({ Test-Path $_ })]
		$FileName,
		
		[Parameter(Mandatory = $true)]
		[string]
		$StatePath
	)
	
	begin {
		$subscriptions = Get-AzSubscription
		$enrollmentAccounts = Get-AzEnrollmentAccount
	}
	process {
		Write-PSFMessage -String 'New-StateDeployment.Processing' -StringValues $FileName
		$scopeObject = New-AzOpsScope -Path (Get-Item -Path $FileName).FullName -StatePath $StatePath
		
		if (-not $scopeObject.Type) {
			Write-PSFMessage -Level Warning -String 'New-StateDeployment.InvalidScope' -StringValues $FileName -Target $scopeObject
			return
		}
		#TODO: Clarify whether this exclusion was intentional
		if ($scopeObject.Type -ne 'subscriptions') { return }
		
		#region Process Subscriptions
		if ($FileName -match '/*.subscription.json$') {
			Write-PSFMessage -String 'New-StateDeployment.Subscription' -StringValues $FileName -Target $scopeObject
			$subscription = $subscriptions | Where-Object Name -EQ $scopeObject.subscriptionDisplayName
			
			#region Subscription needs to be created
			if (-not $subscription) {
				Write-PSFMessage -String 'New-StateDeployment.Subscription.New' -StringValues $FileName -Target $scopeObject
				
				if (-not $enrollmentAccounts) {
					Write-PSFMessage -Level Error -String 'New-StateDeployment.NoEnrollmentAccount' -Target $scopeObject
					Write-PSFMessage -Level Error -String 'New-StateDeployment.NoEnrollmentAccount.Solution' -Target $scopeObject
					return
				}
				
				if ($cfgEnrollmentAccount = Get-PSFConfigValue -FullName 'AzOps.General.EnrollmentAccountPrincipalName') {
					Write-PSFMessage -String 'New-StateDeployment.EnrollmentAccount.Selected' -StringValues $cfgEnrollmentAccount
					$enrollmentAccountObjectId = ($enrollmentAccounts | Where-Object PrincipalName -eq $cfgEnrollmentAccount).ObjectId
				}
				else {
					Write-PSFMessage -String 'New-StateDeployment.EnrollmentAccount.First' -StringValues @($enrollmentAccounts)[0].PrincipalName
					$enrollmentAccountObjectId = @($enrollmentAccounts)[0].ObjectId
				}
				
				Invoke-PSFProtectedCommand -ActionString 'New-StateDeployment.Subscription.Creating' -ActionStringValues $scopeObject.Name -ScriptBlock {
					$subscription = New-AzSubscription -Name $scopeObject.Name -OfferType (Get-PSFConfigValue -FullName 'AzOps.General.OfferType') -EnrollmentAccountObjectId $enrollmentAccountObjectId -ErrorAction Stop
					$subscriptions = @($subscriptions) + @($subscription)
				} -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
				
				Invoke-PSFProtectedCommand -ActionString 'New-StateDeployment.Subscription.AssignManagementGroup' -ActionStringValues $subscription.Name, $scopeObject.ManagementGroupDisplayName -ScriptBlock {
					New-AzManagementGroupSubscription -GroupName $scopeObject.ManagementGroup -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop
				} -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
			}
			#endregion Subscription needs to be created
			#region Subscription exists already
			else {
				Write-PSFMessage -String 'New-StateDeployment.Subscription.Exists' -StringValues $subscription.Name, $subscription.Id -Target $scopeObject
				Invoke-PSFProtectedCommand -ActionString 'New-StateDeployment.Subscription.AssignManagementGroup' -ActionStringValues $subscription.Name, $scopeObject.ManagementGroupDisplayName -ScriptBlock {
					New-AzManagementGroupSubscription -GroupName $scopeObject.ManagementGroup -SubscriptionId $subscription.SubscriptionId -ErrorAction Stop
				} -Target $scopeObject -EnableException $true -PSCmdlet $PSCmdlet
			}
			#endregion Subscription exists already
		}
		if ($FileName -match '/*.providerfeatures.json$') {
			Register-ProviderFeature -FileName $FileName -ScopeObject $scopeObject
		}
		if ($FileName -match '/*.resourceproviders.json$') {
			Register-ResourceProvider -FileName $FileName -ScopeObject $scopeObject
		}
		#endregion Process Subscriptions
	}
}