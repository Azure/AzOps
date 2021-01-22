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
        if ($global:AzOpsSkipRole -eq "1") {
            $skipRole = $true
        }
        else {
            $skipRole = $false
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
                git reset --hard origin/main
            } | Out-Host
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new branch (system)"
            Start-AzOpsNativeExecution {
                git checkout -b system
            } | Out-Host
        }

        Write-AzOpsLog -Level Information -Topic "Initialize-AzOpsRepository" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy -SkipRole:$skipRole

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
                git commit -m 'System pull commit'
            } | Out-Host

            Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin"
            Start-AzOpsNativeExecution {
                git push origin system -f
            } | Out-Null

            switch ($global:SCMPlatform) {
                "GitHub" {
                    # GitHub Labels - Get
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

                    # GitHub PUll Request - List
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

                    # GitHub Pull Request - Wait
                    Start-Sleep -Seconds 5

                    # GitHub Pull Request - Merge (Best Effort)
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
                        Start-AzOpsNativeExecution {
                            gh pr merge $response[0].number --squash --delete-branch -R $global:GitHubRepository
                        } -IgnoreExitcode  | Out-Host
                    }
                    else {
                        Write-AzOpsLog -Level Information -Topic "gh" -Message "Skipping pull request merge"
                    }
                }
                "AzureDevOps" {
                    Write-AzOpsLog -Level Information -Topic "az" -Message "Checking if pull request exists"
                    $response = Start-AzOpsNativeExecution {
                        az repos pr list --status active --output json
                    } | ConvertFrom-Json | ForEach-Object { $_ | Where-Object -FilterScript { $_.sourceRefName -eq "refs/heads/system" } }

                    # Azure DevOps Pull Request - Create
                    if ($null -eq $response) {
                        Write-AzOpsLog -Level Information -Topic "az" -Message "Creating new pull request"
                        Start-AzOpsNativeExecution {
                            az repos pr create --source-branch "refs/heads/system" --target-branch "refs/heads/main" --title $global:AzDevOpsPullRequest --description "Auto-generated PR triggered by Azure Resource Manager `nNew or modified resources discovered in Azure"
                        } | Out-Host
                    }
                    else {
                        Write-AzOpsLog -Level Information -Topic "az" -Message "Skipping pull request creation"
                    }

                    # Azure DevOps Pull Request - Wait
                    Start-Sleep -Second 5

                    # Azure DevOps Pull Request - Merge (Best Effort)
                    if ($global:AzDevOpsAutoMerge -eq 1) {
                        Write-AzOpsLog -Level Information -Topic "az" -Message "Retrieving new pull request"
                        $response = Start-AzOpsNativeExecution {
                            az repos pr list --status active --source-branch "refs/heads/system" --target-branch "refs/heads/main" --output json
                        } | ConvertFrom-Json

                        Write-AzOpsLog -Level Information -Topic "az" -Message "Merging new pull request"
                        Start-AzOpsNativeExecution {
                            az repos pr update --id $response.pullRequestId --auto-complete --delete-source-branch --status completed --squash true
                        } -IgnoreExitcode | Out-Host
                    }
                }
                default {
                    Write-AzOpsLog -Level Error -Topic "none" -Message "Could not determine SCM platform. Current value is $global:SCMPlatform"
                }
            }
        }
    }

    end {}

}