function Invoke-AzOpsGitPushRefresh {

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Operation
    )

    begin {
        if ($env:AZOPS_SKIP_RESOURCE_GROUP -eq "1") {
            $skipResourceGroup = $true
        }
        else {
            $skipResourceGroup = $false
        }
        if ($env:AZOPS_SKIP_POLICY -eq "1") {
            $skipPolicy = $true
        }
        else {
            $skipPolicy = $false
        }
    }

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
                Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy

                Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
                Start-AzOpsNativeExecution {
                    git add --intent-to-add $env:AZOPS_STATE
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
                $diff = Start-AzOpsNativeExecution { 
                    git diff --ignore-space-at-eol --name-only
                }
                
                Write-AzOpsLog -Level Information -Topic "git" -Message "Resetting local main branch"
                Start-AzOpsNativeExecution {
                    git reset --hard
                } | Out-Host
                
                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking if local branch ($env:GITHUB_HEAD_REF) exists"
                $branch = Start-AzOpsNativeExecution {
                    git branch --list $env:GITHUB_HEAD_REF
                }
        
                if ($branch) {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($env:GITHUB_HEAD_REF)"
                    Start-AzOpsNativeExecution {
                        git checkout $env:GITHUB_HEAD_REF
                    } | Out-Host
                }
                else {
                    Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new local branch ($env:GITHUB_HEAD_REF)"
                    Start-AzOpsNativeExecution {
                        git checkout -b $env:GITHUB_HEAD_REF origin/$env:GITHUB_HEAD_REF
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

                Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($env:GITHUB_HEAD_REF)"
                Start-AzOpsNativeExecution {
                    git checkout $env:GITHUB_HEAD_REF
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Pulling origin branch ($env:GITHUB_HEAD_REF) changes"
                Start-AzOpsNativeExecution {
                    git pull origin $env:GITHUB_HEAD_REF
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "git" -Message "Merging origin branch ($env:GITHUB_BASE_REF) changes"
                Start-AzOpsNativeExecution {
                    git merge origin/$env:GITHUB_BASE_REF --no-commit
                } | Out-Host

                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking repository initialization"
                Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy

                Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
                Start-AzOpsNativeExecution {
                    git add $env:AZOPS_STATE
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

                    Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin ($env:GITHUB_HEAD_REF)"
                    Start-AzOpsNativeExecution {
                        git push origin $env:GITHUB_HEAD_REF
                    } | Out-Host
                }
            }
        }
    }
    end {}
}
