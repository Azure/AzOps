function Invoke-AzOpsGitPush {
<#
	.SYNOPSIS
		Applies the current configuration from git to Azure.
	
	.DESCRIPTION
		Applies the current configuration from git to Azure.
		This command supports working with Azure DevOps Services or Github.
	
		It will fetch the current state, then detect changes and apply them if necessary.
		All parameters are optional and can have their values provided by configuration (but that configuration must then also exist in a complete set).
	
	.PARAMETER StatePath
		The path to where the git repository exists.
	
	.PARAMETER ScmPlatform
		A description of the ScmPlatform parameter.
	
	.PARAMETER GithubHeadRef
		TODO: Add content
	
	.PARAMETER GithubComment
		TODO: Add content
	
	.PARAMETER GithubToken
		The PAT with which to authenticate to github.
	
	.PARAMETER AzDevOpsHeadRef
		TODO: Add content
	
	.PARAMETER AzDevOpsApiUrl
		TODO: Add content
	
	.PARAMETER AzDevOpsProjectId
		TODO: Add content
	
	.PARAMETER AzDevOpsRepository
		TODO: Add content
	
	.PARAMETER AzDevOpsPullRequestId
		TODO: Add content
	
	.PARAMETER AzDevOpsToken
		The PAT with which to authenticate to Azure DevOps.
	
	.PARAMETER SkipPolicy
		Skip discovery of policies for better performance.
	
	.PARAMETER SkipRole
		Skip discovery of role.
	
	.PARAMETER SkipResourceGroup
		Skip discovery of resource groups resources for better performance.
	
	.PARAMETER StrictMode
		TODO: Add content
	
	.PARAMETER AzOpsMainTemplate
		TODO: Add content
	
	.EXAMPLE
		PS C:\> Invoke-AzOpsGitPush
	
		Applies the current configuration from git to Azure.
#>
	
	[CmdletBinding()]
	param (
		[string]
		$StatePath = (Get-PSFConfigValue -FullName AzOps.General.State),
		
		[string]
		$ScmPlatform = (Get-PSFConfigValue -FullName AzOps.SCM.Platform),
		
		[string]
		$GithubHeadRef = (Get-PSFConfigValue -FullName AzOps.Github.HeadRef),
		
		[string]
		$GithubComment = (Get-PSFConfigValue -FullName AzOps.Github.Comments),
		
		[string]
		$GithubToken = (Get-PSFConfigValue -FullName AzOps.Github.Token),
		
		[string]
		$AzDevOpsHeadRef = (Get-PSFConfigValue -FullName AzOps.AzDevOps.HeadRef),
		
		[string]
		$AzDevOpsApiUrl = (Get-PSFConfigValue -FullName AzOps.AzDevOps.ApiUrl),
		
		[string]
		$AzDevOpsProjectId = (Get-PSFConfigValue -FullName AzOps.AzDevOps.ProjectId),
		
		[string]
		$AzDevOpsRepository = (Get-PSFConfigValue -FullName AzOps.AzDevOps.Repository),
		
		[string]
		$AzDevOpsPullRequestId = (Get-PSFConfigValue -FullName AzOps.AzDevOps.PullRequestId),
		
		[string]
		$AzDevOpsToken = (Get-PSFConfigValue -FullName AzOps.AzDevOps.Token),
		
		[switch]
		$SkipResourceGroup = (Get-PSFConfigValue -FullName AzOps.General.SkipResourceGroup),
		
		[switch]
		$SkipPolicy = (Get-PSFConfigValue -FullName AzOps.General.SkipPolicy),
		
		[switch]
		$SkipRole = (Get-PSFConfigValue -FullName AzOps.General.SkipRole),
		
		[switch]
		$StrictMode = (Get-PSFConfigValue -FullName AzOps.General.StrictMode),
		
		[string]
		$AzOpsMainTemplate = (Get-PSFConfigValue -FullName AzOps.General.MainTemplate)
	)
	
	begin {
		if ($ScmPlatform -notin 'Github', 'AzureDevOps') {
			Stop-PSFFunction -String 'Invoke-AzOpsGitPush.Invalid.Platform' -StringValues $ScmPlatform -EnableException $true -Cmdlet $PSCmdlet -Category InvalidArgument
		}
		$headRef = switch ($ScmPlatform) {
			"GitHub" { $GithubHeadRef }
			"AzureDevOps" { $AzDevOpsHeadRef }
		}
		
		Push-Location -Path $StatePath
		
		# Skip AzDevOps Run
		$skipChange = $false
		
		$common = @{
			Level = "Host"
			Tag   = 'git'
		}
		
		# Ensure git on the host has info about origin
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Fetch'
		Invoke-NativeCommand -ScriptBlock { git fetch origin } | Out-Host
		
		# If not in strict mode: quit begin and continue with process
		if (-not $StrictMode) { return }
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.StrictMode'
		
		#region Checkout & Update local repository
		#TODO: Clarify redundancy
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Fetch'
		Invoke-NativeCommand -ScriptBlock { git fetch origin } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Checkout' -StringValues main
		Invoke-NativeCommand -ScriptBlock { git checkout origin/main } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Pull' -StringValues main
		Invoke-NativeCommand -ScriptBlock { git pull origin main } | Out-Host
		
		Write-PSFMessage -Level Host -String 'Invoke-AzOpsGitPush.Repository.Initialize'
		$parameters = $PSBoundParameters | ConvertTo-PSFHashtable -Inherit -Include SkipResourceGroup, SkipPolicy, SkipRole, StatePath
		Initialize-AzOpsRepository -InvalidateCache -Rebuild @parameters
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Add'
		Invoke-NativeCommand -ScriptBlock { git add --intent-to-add $StatePath } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Diff'
		$diff = Invoke-NativeCommand -ScriptBlock { git diff --ignore-space-at-eol --name-status }
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Reset'
		Invoke-NativeCommand -ScriptBlock { git reset --hard } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Branch' -StringValues $headRef
		$branch = Invoke-NativeCommand -ScriptBlock { git branch --list $headRef }
		
		if ($branch) {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Checkout.Existing' -StringValues $headRef
			Invoke-NativeCommand -ScriptBlock { git checkout $headRef } | Out-Host
		}
		else {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Checkout.New' -StringValues $headRef
			Invoke-NativeCommand -ScriptBlock { git checkout -b $headRef origin/$headRef } | Out-Host
		}
		#endregion Checkout & Update local repository
		
		if (-not $diff) {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.IsConsistent'
			return
		}
		
		#region Inconsistent State
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Changes'
		$output = foreach ($entry in $diff -join "," -split ",") {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Changes.Item' -StringValues $entry
			'`{0}`' -f $entry
		}
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Rest.PR.Comment'
		switch ($ScmPlatform) {
			"GitHub" {
				Write-PSFMessage -String 'Invoke-AzOpsGitPush.Github.Uri' -StringValues $GithubComment
				$params = @{
					Headers = @{
						"Authorization" = "Bearer $GithubToken"
						"Content-Type"  = "application/json"
					}
					Body    = @{ body = "$(Get-Content -Path "$script:ModuleRoot/data/auxiliary/guidance/strict/github/README.md" -Raw) `n Changes: `n`n$($output -join "`n`n")" } | ConvertTo-Json
				}
				$null = Invoke-RestMethod -Method "Post" -Uri $GithubComment @params
				#TODO: Clarify Intent
				exit 1
			}
			"AzureDevOps" {
				$params = @{
					Uri = "$($AzDevOpsApiUrl)$($AzDevOpsProjectId)/_apis/git/repositories/$AzDevOpsRepository/pullRequests/$AzDevOpsPullRequestId/threads?api-version=5.1"
					Method = "Post"
					Headers = @{
						"Authorization" = "Bearer $AzDevOpsToken"
						"Content-Type"  = "application/json"
					}
					Body = @{
						comments = @(
							@{
								"parentCommentId" = 0
								"content"		  = "$(Get-Content -Path "$script:ModuleRoot/data/auxiliary/guidance/strict/azdevops/README.md" -Raw) `n Changes: `n`n$($output -join "`n`n")"
								"commentType"	  = 1
							}
						)
					} | ConvertTo-Json -Depth 5
				}
				Invoke-RestMethod @params
				#TODO: Clarify Intent
				exit 1
			}
		}
		#endregion Inconsistent State
	}
	
	process {
		#region Change
		switch ($ScmPlatform) {
			"GitHub" {
				$changeSet = Invoke-NativeCommand -ScriptBlock {
					git diff origin/main --ignore-space-at-eol --name-status
				}
			}
			"AzureDevOps" {
				Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.AzDevOps.Branch.Switch'
				Invoke-NativeCommand -ScriptBlock { git checkout $AzDevOpsHeadRef } | Out-Host
				
				$commitMessage = Invoke-NativeCommand -ScriptBlock { git log -1 --pretty=format:%s }
				Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.AzDevOps.Commit.Message' -StringValues $commitMessage
				
				#TODO: Clarify whether this really should only be checked for Azure DevOps
				if ($commitMessage -match "System push commit") {
					$skipChange = $true
				}
				
				if ($skipChange -eq $true) {
					$changeSet = @()
				}
				else {
					$changeSet = Invoke-NativeCommand -ScriptBlock {
						git diff origin/main --ignore-space-at-eol --name-status
					}
				}
			}
		}
		if ($changeSet) {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.AzOps.Change.Invoke'
			Invoke-AzOpsChange -ChangeSet $changeSet -StatePath $StatePath -AzOpsMainTemplate $AzOpsMainTemplate
		}
		else {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.AzOps.Change.Skipped'
		}
		#endregion Change
	}
	
	end {
		if ($skipChange) {
			Pop-Location
			return
		}
		
		#region Rebuild
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Checkout' -StringValues $headRef
		Invoke-NativeCommand -ScriptBlock { git checkout $headRef } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Pull' -StringValues $headRef
		Invoke-NativeCommand -ScriptBlock { git pull origin $headRef } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.AzOps.Initialize'
		Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy -SkipRole:$SkipRole -StatePath $StatePath
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Add'
		Invoke-NativeCommand -ScriptBlock { git add $StatePath } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Status'
		$status = Invoke-NativeCommand -ScriptBlock { git status --short }
		if (-not $status) {
			Pop-Location
			return
		}
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Commit'
		Invoke-NativeCommand -ScriptBlock { git commit -m 'System push commit' } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPush.Git.Change.Push' -StringValues $headRef
		Invoke-NativeCommand -ScriptBlock { git push origin $headRef } | Out-Host
		#endregion Rebuild
		
		Pop-Location
	}
}