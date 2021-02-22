function Invoke-AzOpsGitPull {

    <#
        .SYNOPSIS
            Updates the AzOps ARM configuration in the connected repository.
        .DESCRIPTION
            Updates the AzOps ARM configuration in the connected repository.
            This command supports working with Azure DevOps Services or GitHub.
            It will fetch the current state, update it and if needed create a PR and even merge it.
            All parameters are optional and can have their values provided by configuration (but that configuration must then also exist in a complete set).
        .PARAMETER StatePath
            The path to where the git repository exists.
        .PARAMETER GitHubApiUrl
            The Url pointing at the github API root.
        .PARAMETER GitHubRepository
            The name of the GitHub repository to work with.
        .PARAMETER GitHubToken
            The PAT with which to authenticate to github.
        .PARAMETER GitHubPullRequest
            The title of the Pull Request that adds the changes.
        .PARAMETER GitHubAutoMerge
            Whether the GitHub PR should be merged automatically,
        .PARAMETER AzDevOpsPullRequest
            The title of the Pull Request that adds the changes.
        .PARAMETER AzDevOpsAutoMerge
            Whether the Azure DevOps PR should be merged automatically.
        .PARAMETER ScmPlatform
            Which platform to work with.
            Defaults to GitHub, supports GitHub & AzureDevOps
        .PARAMETER SkipPolicy
            Skip discovery of policies for better performance.
        .PARAMETER SkipRole
            Skip discovery of role.
        .PARAMETER SkipResourceGroup
            Skip discovery of resource groups resources for better performance.
        .EXAMPLE
            > Invoke-AzOpsGitPull
            Updates the AzOps ARM configuration in the connected repository.
            Settings are picked up from configuration.
    #>

    [CmdletBinding(DefaultParameterSetName = 'GitHub')]
    param (
        [string]
        $StatePath = (Get-PSFConfigValue -FullName AzOps.Core.State),

        [Parameter(ParameterSetName = 'GitHub')]
        [string]
        $GitHubApiUrl = (Get-PSFConfigValue -FullName AzOps.Actions.ApiUrl),

        [Parameter(ParameterSetName = 'GitHub')]
        [string]
        $GitHubRepository = (Get-PSFConfigValue -FullName AzOps.Actions.Repository),

        [Parameter(ParameterSetName = 'GitHub')]
        [string]
        $GitHubToken = (Get-PSFConfigValue -FullName AzOps.Actions.Token),

        [Parameter(ParameterSetName = 'GitHub')]
        [string]
        $GitHubPullRequest = (Get-PSFConfigValue -FullName AzOps.Actions.PullRequest),

        [Parameter(ParameterSetName = 'GitHub')]
        [switch]
        $GitHubAutoMerge = (Get-PSFConfigValue -FullName AzOps.Actions.AutoMerge),

        [Parameter(ParameterSetName = 'AzDevOps')]
        [string]
        $AzDevOpsPullRequest = (Get-PSFConfigValue -FullName AzOps.Pipelines.PullRequest),

        [Parameter(ParameterSetName = 'AzDevOps')]
        [switch]
        $AzDevOpsAutoMerge = (Get-PSFConfigValue -FullName AzOps.Pipelines.AutoMerge),

        [string]
        $ScmPlatform = (Get-PSFConfigValue -FullName AzOps.Core.SourceControl),

        [switch]
        $SkipResourceGroup = (Get-PSFConfigValue -FullName AzOps.Core.SkipResourceGroup),

        [switch]
        $SkipPolicy = (Get-PSFConfigValue -FullName AzOps.Core.SkipPolicy),

        [switch]
        $SkipRole = (Get-PSFConfigValue -FullName AzOps.Core.SkipRole)
    )

    begin {
        $common = @{
            Level = "Host"
            Tag   = 'git'
        }

        Push-Location -Path $StatePath
    }

    process {
        #region Fetching & Checking Out
        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Fetching'
        Invoke-AzOpsNativeCommand -ScriptBlock { git fetch } | Out-Host

        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut'
        $branch = Invoke-AzOpsNativeCommand -ScriptBlock { git branch --remote | grep 'origin/system' } -IgnoreExitcode

        if ($branch) {
            Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut.Exists'
            Invoke-AzOpsNativeCommand -ScriptBlock {
                git checkout system
                git reset --hard origin/main
            } | Out-Host
        }
        else {
            Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.CheckingOut.New'
            Invoke-AzOpsNativeCommand -ScriptBlock { git checkout -b system } | Out-Host
        }
        #endregion Fetching & Checking Out

        #region Updating and checking for delta
        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Initialize.Repository'
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$SkipResourceGroup -SkipPolicy:$SkipPolicy -SkipRole:$SkipRole -StatePath $StatePath

        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Add'
        Invoke-AzOpsNativeCommand -ScriptBlock { git add $StatePath } | Out-Host

        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Status'
        $status = Invoke-AzOpsNativeCommand -ScriptBlock { git status --short }
        #endregion Updating and checking for delta

        # If nothing changed, nothing to do, so quit
        if (-not $status) { return }

        #region Commit & Push
        $status -split ("`n") | ForEach-Object {
            Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Status.Message' -StringValues $_
        }

        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Commit'
        Invoke-AzOpsNativeCommand -ScriptBlock {
            git commit -m 'System pull commit'
        } | Out-Host

        Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Git.Push'
        Invoke-AzOpsNativeCommand -ScriptBlock {
            git push origin system -f
        } | Out-Null
        #endregion Commit & Push

        switch ($ScmPlatform) {
            #region GitHub
            "GitHub" {
                #region GitHub - Labels
                Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.Labels.Get'
                #TODO: Replace REST call when GH CLI paging support is available
                $params = @{
                    Uri     = "$GitHubApiUrl/repos/$GitHubRepository/labels"
                    Headers = @{
                        "Authorization" = "Bearer $GitHubToken"
                    }
                }
                $response = Invoke-RestMethod -Method "Get" @params | Where-Object name -like "system"

                if (-not $response) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.Labels.Create'
                    #TODO: Replace REST call when GH CLI paging support is available
                    $params = @{
                        Uri     = "$GitHubApiUrl/repos/$GitHubRepository/labels"
                        Headers = @{
                            "Authorization" = "Bearer $GitHubToken"
                            "Content-Type"  = "application/json"
                        }
                        Body    = (@{
                                "name"        = "system"
                                "description" = "[AzOps] Do not delete"
                                "color"       = "db9436"
                            } | ConvertTo-Json)
                    }
                    $response = Invoke-RestMethod -Method "Post" @params
                }
                #endregion GitHub - Labels

                # GitHub PUll Request - List
                Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.Check'
                #TODO: Replace REST call when GH CLI paging support is available
                $params = @{
                    Uri     = "$GitHubApiUrl/repos/$GitHubRepository/pulls?state=open&head=$($GitHubRepository):system"
                    Headers = @{
                        "Authorization" = "Bearer $GitHubToken"
                    }
                }
                $response = Invoke-RestMethod -Method "Get" @params

                # GitHub Pull Request - Create
                if (-not $response) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.Create'
                    Invoke-AzOpsNativeCommand -ScriptBlock {
                        gh pr create --title $GitHubPullRequest --body "Auto-generated PR triggered by Azure Resource Manager" --label "system" --repo $GitHubRepository
                    } | Out-Host
                }
                else {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.NoOp'
                }

                # GitHub Pull Request - Wait
                Start-Sleep -Seconds 5

                # GitHub Pull Request - Merge (Best Effort)
                if ($GitHubAutoMerge) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.Get'
                    $params = @{
                        Uri     = "$GitHubApiUrl/repos/$GitHubRepository/pulls?state=open&head=$($GitHubRepository):system"
                        Headers = @{
                            "Authorization" = "Bearer $GitHubToken"
                        }
                    }
                    $response = Invoke-RestMethod -Method "Get" @params

                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.Merge'
                    Invoke-AzOpsNativeCommand -ScriptBlock {
                        gh pr merge @($response)[0].number --squash --delete-branch -R $GitHubRepository
                    } -IgnoreExitcode | Out-Host
                }
                else {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.Actions.PR.NoMerge'
                }
            }
            #endregion GitHub
            #region Azure DevOps
            "AzureDevOps" {
                Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Check'
                $response = Invoke-AzOpsNativeCommand -ScriptBlock {
                    az repos pr list --status active --output json
                } | ConvertFrom-Json | ForEach-Object { $_ | Where-Object sourceRefName -eq "refs/heads/system" }

                # Azure DevOps Pull Request - Create
                if (-not $response) {
                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Create'
                    Invoke-AzOpsNativeCommand -ScriptBlock {
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
                    $response = Invoke-AzOpsNativeCommand -ScriptBlock {
                        az repos pr list --status active --source-branch "refs/heads/system" --target-branch "refs/heads/main" --output json
                    } | ConvertFrom-Json

                    Write-PSFMessage @common -String 'Invoke-AzOpsGitPull.AzDev.PR.Merge'
                    Invoke-AzOpsNativeCommand -ScriptBlock {
                        az repos pr update --id $response.pullRequestId --auto-complete --delete-source-branch --status completed --squash true
                    } -IgnoreExitcode | Out-Host
                }
            }
            #endregion Azure DevOps
            default {
                Write-PSFMessage -Level Warning -String 'Invoke-AzOpsGitPull.SCM.Unknown'
                Write-Error "Could not determine SCM platform. Current value is $ScmPlatform"
            }
        }
    }

    end {
        Pop-Location
    }
}