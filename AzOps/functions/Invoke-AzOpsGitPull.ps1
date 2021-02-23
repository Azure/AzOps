function Invoke-AzOpsGitPull {
<#
	.SYNOPSIS
		Updates the AzOps ARM configuration in the connected repository.
	
	.DESCRIPTION
		Updates the AzOps ARM configuration in the connected repository.
		This command supports working with Azure DevOps Services or Github.
	
		It will fetch the current state, update it and if needed create a PR and even merge it.
		All parameters are optional and can have their values provided by configuration (but that configuration must then also exist in a complete set).
	
	.PARAMETER StatePath
		The path to where the git repository exists.
	
	.PARAMETER GithubApiUrl
		The Url pointing at the github API root.
	
	.PARAMETER GithubRepository
		The name of the Github repository to work with.
	
	.PARAMETER GithubToken
		The PAT with which to authenticate to github.
	
	.PARAMETER GithubPullRequest
		The title of the Pull Request that adds the changes.
	
	.PARAMETER GithubAutoMerge
		Whether the Github PR should be merged automatically,
	
	.PARAMETER AzDevOpsPullRequest
		The title of the Pull Request that adds the changes.
	
	.PARAMETER AzDevOpsAutoMerge
		Whether the Azure DevOps PR should be merged automatically.
	
	.PARAMETER ScmPlatform
		Which platform to work with.
		Defaults to Github, supports Github & AzureDevOps
	
	.PARAMETER SkipPolicy
		Skip discovery of policies for better performance.
	
	.PARAMETER SkipRole
		Skip discovery of role.
	
	.PARAMETER SkipResourceGroup
		Skip discovery of resource groups resources for better performance.
	
	.EXAMPLE
		PS C:\> Invoke-AzOpsGitPull
	
		Updates the AzOps ARM configuration in the connected repository.
		Settings are picked up from configuration.
#>
	
	[CmdletBinding(DefaultParameterSetName = 'Github')]
	param (
		[string]
		$StatePath = (Get-PSFConfigValue -FullName AzOps.General.State),
		
		[Parameter(ParameterSetName = 'Github')]
		[string]
		$GithubApiUrl = (Get-PSFConfigValue -FullName AzOps.Github.ApiUrl),
		
		[Parameter(ParameterSetName = 'Github')]
		[string]
		$GithubRepository = (Get-PSFConfigValue -FullName AzOps.Github.Repository),
		
		[Parameter(ParameterSetName = 'Github')]
		[string]
		$GithubToken = (Get-PSFConfigValue -FullName AzOps.Github.Token),
		
		[Parameter(ParameterSetName = 'Github')]
		[string]
		$GithubPullRequest = (Get-PSFConfigValue -FullName AzOps.Github.PullRequest),
		
		[Parameter(ParameterSetName = 'Github')]
		[switch]
		$GithubAutoMerge = (Get-PSFConfigValue -FullName AzOps.Github.AutoMerge),
		
		[Parameter(ParameterSetName = 'AzDevOps')]
		[string]
		$AzDevOpsPullRequest = (Get-PSFConfigValue -FullName AzOps.AzDevOps.PullRequest),
		
		[Parameter(ParameterSetName = 'AzDevOps')]
		[switch]
		$AzDevOpsAutoMerge = (Get-PSFConfigValue -FullName AzOps.AzDevOps.AutoMerge),
		
		[string]
		$ScmPlatform = (Get-PSFConfigValue -FullName AzOps.SCM.Platform),
		
		[switch]
		$SkipResourceGroup = (Get-PSFConfigValue -FullName AzOps.General.SkipResourceGroup),
		
		[switch]
		$SkipPolicy = (Get-PSFConfigValue -FullName AzOps.General.SkipPolicy),
		
		[switch]
		$SkipRole = (Get-PSFConfigValue -FullName AzOps.General.SkipRole)
	)
	begin {
		$common = @{
			Level = "Host"
			Tag = 'git'
		}
		
		Push-Location -Path $StatePath
	}
	process {
		#region Fetching & Checking Out
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Fetching'
		Invoke-NativeCommand -ScriptBlock { git fetch } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut'
		$branch = Invoke-NativeCommand -ScriptBlock { git branch --remote | grep 'origin/system' } -IgnoreExitcode
		
		if ($branch) {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut.Exists'
			Invoke-NativeCommand -ScriptBlock {
				git checkout system
				git reset --hard origin/main
			} | Out-Host
		}
		else {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut.New'
			Invoke-NativeCommand -ScriptBlock { git checkout -b system } | Out-Host
		}
		#endregion Fetching & Checking Out
		
		#region Updating and checking for delta
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Initialize.Repository'
		Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$SkipResourceGroup -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -StatePath $StatePath
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Add'
		Invoke-NativeCommand -ScriptBlock { git add $StatePath } | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Status'
		$status = Invoke-NativeCommand -ScriptBlock { git status --short }
		#endregion Updating and checking for delta
		
		# If nothing changed, nothing to do, so quit
		if (-not $status) { return }
		
		#region Commit & Push
		$status -split ("`n") | ForEach-Object {
			Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Status.Message' -StringValues $_
		}
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Commit'
		Invoke-NativeCommand -ScriptBlock {
			git commit -m 'System pull commit'
		} | Out-Host
		
		Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Push'
		Invoke-NativeCommand -ScriptBlock {
			git push origin system -f
		} | Out-Null
		#endregion Commit & Push
		
		switch ($ScmPlatform) {
			#region Github
			"GitHub" {
				#region Github - Labels
				Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.Labels.Get'
				#TODO: Replace REST call when GH CLI paging support is available
				$params = @{
					Uri	    = "$GithubApiUrl/repos/$GithubRepository/labels"
					Headers = @{
						"Authorization" = "Bearer $GithubToken"
					}
				}
				$response = Invoke-RestMethod -Method "Get" @params | Where-Object name -like "system"
				
				if (-not $response) {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.Labels.Create'
					#TODO: Replace REST call when GH CLI paging support is available
					$params = @{
						Uri	    = "$GithubApiUrl/repos/$GithubRepository/labels"
						Headers = @{
							"Authorization" = "Bearer $GithubToken"
							"Content-Type"  = "application/json"
						}
						Body    = (@{
								"name"	      = "system"
								"description" = "[AzOps] Do not delete"
								"color"	      = "db9436"
							} | ConvertTo-Json)
					}
					$response = Invoke-RestMethod -Method "Post" @params
				}
				#endregion Github - Labels
				
				# GitHub PUll Request - List
				Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.Check'
				#TODO: Replace REST call when GH CLI paging support is available
				$params = @{
					Uri	    = "$GithubApiUrl/repos/$GithubRepository/pulls?state=open&head=$($GithubRepository):system"
					Headers = @{
						"Authorization" = "Bearer $GithubToken"
					}
				}
				$response = Invoke-RestMethod -Method "Get" @params
				
				# GitHub Pull Request - Create
				if (-not $response) {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.Create'
					Invoke-NativeCommand -ScriptBlock {
						gh pr create --title $GithubPullRequest --body "Auto-generated PR triggered by Azure Resource Manager" --label "system" --repo $GithubRepository
					} | Out-Host
				}
				else {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.NoOp'
				}
				
				# GitHub Pull Request - Wait
				Start-Sleep -Seconds 5
				
				# GitHub Pull Request - Merge (Best Effort)
				if ($GithubAutoMerge) {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.Get'
					$params = @{
						Uri	    = "$GithubApiUrl/repos/$GithubRepository/pulls?state=open&head=$($GithubRepository):system"
						Headers = @{
							"Authorization" = "Bearer $GithubToken"
						}
					}
					$response = Invoke-RestMethod -Method "Get" @params
					
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.Merge'
					Invoke-NativeCommand -ScriptBlock {
						gh pr merge @($response)[0].number --squash --delete-branch -R $GithubRepository
					} -IgnoreExitcode | Out-Host
				}
				else {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Github.PR.NoMerge'
				}
			}
			#endregion Github
			#region Azure DevOps
			"AzureDevOps" {
				Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Check'
				$response = Invoke-NativeCommand -ScriptBlock {
					az repos pr list --status active --output json
				} | ConvertFrom-Json | ForEach-Object { $_ | Where-Object sourceRefName -eq "refs/heads/system" }
				
				# Azure DevOps Pull Request - Create
				if (-not $response) {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Create'
					Invoke-NativeCommand -ScriptBlock {
						az repos pr create --source-branch "refs/heads/system" --target-branch "refs/heads/main" --title $AzDevOpsPullRequest --description "Auto-generated PR triggered by Azure Resource Manager `nNew or modified resources discovered in Azure"
					} | Out-Host
				}
				else {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.NoneNeeded'
				}
				
				# Azure DevOps Pull Request - Wait
				Start-Sleep -Seconds 5
				
				# Azure DevOps Pull Request - Merge (Best Effort)
				if ($AzDevOpsAutoMerge) {
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Get'
					$response = Invoke-NativeCommand -ScriptBlock {
						az repos pr list --status active --source-branch "refs/heads/system" --target-branch "refs/heads/main" --output json
					} | ConvertFrom-Json
					
					Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Merge'
					Invoke-NativeCommand -ScriptBlock {
						az repos pr update --id $response.pullRequestId --auto-complete --delete-source-branch --status completed --squash true
					} -IgnoreExitcode | Out-Host
				}
			}
			#endregion Azure DevOps
			default {
				Write-PSFMessage -Level Warning -String 'Invoke-AzOpsGitPull.SCM.Unknown' -StringValues $ScmPlatform
				Pop-Location
				throw "Could not determine SCM platform. Current value is $ScmPlatform"
			}
		}
	}
	
	end {
		Pop-Location
	}
}