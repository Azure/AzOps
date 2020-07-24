function Invoke-AzOpsGitPull {

    [CmdletBinding()]
    [OutputType()]
    param ()

    begin {
        if ($global:AzOpsSkipResourceGroup -eq "1") {
            $skipResourceGroup = $true
        }
        else {
            $skipResourceGroup = $false
        }
        if ($global:AzOpsSkipPolicy -eq "1") {
            $skipPolicy = $true
        }
        else {
            $skipPolicy = $false
        }
    }

    process {
        Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest changes"
        Start-AzOpsNativeExecution {
            git fetch
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for branch (system)"
        $branch = Start-AzOpsNativeExecution {
            git branch --remote | grep 'origin/system'
        } -IgnoreExitcode

        if ($branch) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing branch (system)"
            Start-AzOpsNativeExecution {
                git checkout system
                git merge origin/main --strategy-option theirs --allow-unrelated-histories
            } | Out-Host
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new branch (system)"
            Start-AzOpsNativeExecution {
                git checkout -b system
            } | Out-Host
        }

        Write-AzOpsLog -Level Information -Topic "Initialize-AzOpsRepository" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy

        Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
        Start-AzOpsNativeExecution {
            git add $global:AzOpsState
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
        $status = Start-AzOpsNativeExecution {
            git status --short
        }

        if ($status) {
            $status -split ("`n") | ForEach-Object {
                Write-AzOpsLog -Level Information -Topic "git" -Message $_
            }

            Write-AzOpsLog -Level Information -Topic "git" -Message "Creating new commit"
            Start-AzOpsNativeExecution {
                git commit -m 'System commit'
            } | Out-Host

            Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin"
            Start-AzOpsNativeExecution {
                git push origin system
            } | Out-Null

            # GitHub Labels
            Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if label (system) exists"
            # TODO: Replace REST call when GH CLI paging support is available
            $params = @{
                Uri     = ($global:GitHubApiUrl + "/repos/" + $global:GitHubRepository + "/labels")
                Headers = @{
                    "Authorization" = ("Bearer " + $global:GitHubToken)
                }
            }
            $response = Invoke-RestMethod -Method "Get" @params | Where-Object -FilterScript { $_.name -like "system" }

            if (-not $response) {
                # GitHub Labels - Create
                Write-AzOpsLog -Level Information -Topic "rest" -Message "Creating new label (system)"
                # TODO: Replace REST call when GH CLI paging support is available
                $params = @{
                    Uri     = ($global:GitHubApiUrl + "/repos/" + $global:GitHubRepository + "/labels")
                    Headers = @{
                        "Authorization" = ("Bearer " + $global:GitHubToken)
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

            Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if pull request exists"
            # TODO: Replace REST call when GH CLI paging support is available
            $params = @{
                Uri     = ($global:GitHubApiUrl + "/repos/" + $global:GitHubRepository + ("/pulls?state=open&head=") + $global:GitHubRepository + ":system")
                Headers = @{
                    "Authorization" = ("Bearer " + $global:GitHubToken)
                }
            }
            $response = Invoke-RestMethod -Method "Get" @params

            # GitHub Pull Request - Create
            if (-not $response) {
                Write-AzOpsLog -Level Information -Topic "gh" -Message "Creating new pull request"
                Start-AzOpsNativeExecution {
                    gh pr create --title $global:GitHubPullRequest --body "Auto-generated PR triggered by Azure Resource Manager" --label "system" --repo $global:GitHubRepository
                } | Out-Host
            }
            else {
                Write-AzOpsLog -Level Information -Topic "gh" -Message "Skipping pull request creation"
            }

            # GitHub Pull Request - Merge
            if ($global:GitHubAutoMerge -eq 1) {
                Write-AzOpsLog -Level Information -Topic "rest" -Message "Retrieving new pull request"
                $params = @{
                    Uri     = ($global:GitHubApiUrl + "/repos/" + $global:GitHubRepository + ("/pulls?state=open&head=") + $global:GitHubRepository + ":system")
                    Headers = @{
                        "Authorization" = ("Bearer " + $global:GitHubToken)
                    }
                }
                $response = Invoke-RestMethod -Method "Get" @params

                Write-AzOpsLog -Level Information -Topic "gh" -Message "Merging new pull request"
                try {
                    Start-AzOpsNativeExecution {
                        gh pr merge $response[0].number --squash --delete-branch -R $global:GitHubRepository
                    } | Out-Host
                }
                catch {
                    $params = @{
                        Headers = @{
                            "Authorization" = ("Bearer " + $global:GitHubToken)
                        }
                        Body    = (@{
                                "body" = "$(Get-Content -Path "$PSScriptRoot/../auxiliary/merge/README.md" -Raw)"
                            } | ConvertTo-Json)
                    }
                    Invoke-RestMethod -Method "POST" -Uri ($global:GitHubApiUrl + "/repos/" + $global:GitHubRepository + "/issues/" + $response[0].number + "/comments") @params | Out-Null
                }
            }
            else {
                Write-AzOpsLog -Level Information -Topic "gh" -Message "Skipping pull request merge"
            }
        }
    }

    end {}

}