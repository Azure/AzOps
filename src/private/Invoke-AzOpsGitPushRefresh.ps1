function Invoke-AzOpsGitPushRefresh {

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Operation,
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,
        [Parameter(Mandatory = $true)]
        [string]$HeadBranch
    )

    begin {}

    process {
        switch ($operation) {
            "Before" {
                Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest origin changes"
                Start-AzOpsNativeExecution {
                    git fetch origin
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out origin branch (main)"
                Start-AzOpsNativeExecution {
                    git checkout origin/main
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Pulling origin branch (main) changes"
                Start-AzOpsNativeExecution {
                    git pull origin main
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
                Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup

                Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
                Start-AzOpsNativeExecution {
                    git add --intent-to-add azops/
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
                $diff = Start-AzOpsNativeExecution { 
                    git diff --ignore-space-at-eol --name-only
                }
                
                Write-AzOpsLog -Level Information -Topic "git" -Message "Resetting local main branch"
                Start-AzOpsNativeExecution {
                    git reset --hard
                } | Out-Host
                
                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking if local branch ($headBranch) exists"
                $branch = Start-AzOpsNativeExecution {
                    git branch --list $headBranch
                }
        
                if ($branch) {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($headBranch)"
                    Start-AzOpsNativeExecution {
                        git checkout $headBranch
                    } | Out-Host
                }
                else {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new local branch ($headBranch)"
                    Start-AzOpsNativeExecution {
                        git checkout -b $headBranch origin/$headBranch
                    } | Out-Host
                }
        
                if ($Diff) {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Formatting diff changes"
                    $Diff = $Diff -join ","
                }

                return $diff
            }
            "After" {
                Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest origin changes"
                Start-AzOpsNativeExecution {
                    git fetch origin
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($headBranch)"
                Start-AzOpsNativeExecution {
                    git checkout $headBranch
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Pulling origin branch ($headBranch) changes"
                Start-AzOpsNativeExecution {
                    git pull origin $headBranch
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Merging origin branch ($baseBranch) changes"
                Start-AzOpsNativeExecution {
                    git merge origin/$baseBranch --no-commit
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
                Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup

                Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
                Start-AzOpsNativeExecution {
                    git add azops/
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
                $status = Start-AzOpsNativeExecution {
                    git status --short
                }

                if ($status) {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Creating new commit"
                    Start-AzOpsNativeExecution {
                        git commit -m 'System commit'
                    } | Out-Host

                    Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin ($headBranch)"
                    Start-AzOpsNativeExecution {
                        git push origin $headBranch
                    } | Out-Host
                }
            }
        }
    }
    end {}
}
