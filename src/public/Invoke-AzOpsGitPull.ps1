function Invoke-AzOpsGitPull {
    
    [CmdletBinding()]
    [OutputType()]
    param ()

    begin {}

    process {
        Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest changes"
        Start-AzOpsNativeExecution {
            git fetch
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for branch (system) existence"
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

        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking refresh process"
        Invoke-AzOpsGitPullRefresh

        Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
        Start-AzOpsNativeExecution {
            git add $env:AZOPS_STATE
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

            Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if label (system) exists"
            $params = @{
                Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + "/labels")
                Headers = @{
                    "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
                }
            }
            $response = Invoke-RestMethod -Method "Get" @params | Where-Object -FilterScript { $_.name -like "system" }

            if (!$response) {
                Write-AzOpsLog -Level Information -Topic "rest" -Message "Creating new label (system)"
                $params = @{
                    Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + "/labels")
                    Headers = @{
                        "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
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
            $params = @{
                Uri     = ($env:GITHUB_API_URL + "/repos/" + $env:GITHUB_REPOSITORY + ("/pulls?state=open&head=") + $env:GITHUB_REPOSITORY + ":system")
                Headers = @{
                    "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
                }
            }
            $response = Invoke-RestMethod -Method "Get" @params

            if (!$response) {
                Write-AzOpsLog -Level Information -Topic "gh" -Message "Creating new pull request"
                Start-AzOpsNativeExecution {
                    gh pr create --title $env:GITHUB_PULL_REQUEST --body "Auto-generated PR triggered by Azure Resource Manager `nNew or modified resources discovered in Azure" --label "system" --repo $env:GITHUB_REPOSITORY
                } | Out-Host
            }
            else {
                Write-AzOpsLog -Level Information -Topic "gh" -Message "Skipping pull request creation"
            }
        }
    }

    end {}

}