function Invoke-AzOpsGitPush {

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

        Write-AzOpsLog -Level Information -Topic "Initialize-AzOpsRepository" -Message "Invoking repository initialization"
        Initialize-AzOpsRepository -InvalidateCache -Rebuild -SkipResourceGroup:$skipResourceGroup -SkipPolicy:$skipPolicy

        Write-AzOpsLog -Level Information -Topic "git" -Message "Adding azops file changes"
        Start-AzOpsNativeExecution {
            git add --intent-to-add $global:AzOpsState
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
        $diff = Start-AzOpsNativeExecution {
            git diff --ignore-space-at-eol --name-status
        }

        Write-AzOpsLog -Level Information -Topic "git" -Message "Resetting local main branch"
        Start-AzOpsNativeExecution {
            git reset --hard
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking if local branch ($global:GitHubHeadRef) exists"
        $branch = Start-AzOpsNativeExecution {
            git branch --list $global:GitHubHeadRef
        }

        if ($branch) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($global:GitHubHeadRef)"
            Start-AzOpsNativeExecution {
                git checkout $global:GitHubHeadRef
            } | Out-Host
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out new local branch ($global:GitHubHeadRef)"
            Start-AzOpsNativeExecution {
                git checkout -b $global:GitHubHeadRef origin/$global:GitHubHeadRef
            } | Out-Host
        }

        if ($diff) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Formatting diff changes"
            $diff = $diff -join ","
        }

        if ($null -ne $diff) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Changes:"
            $output = @()
            $diff.Split(",") | ForEach-Object {
                $output += ( "``" + $_ + "``")
                $output += "`n`n"
                Write-AzOpsLog -Level Information -Topic "git" -Message $_
            }

            if ($global:AzOpsStrictMode -eq 1) {
                Write-AzOpsLog -Level Information -Topic "git" -Message "Branch is not consistent with Azure"
                Write-AzOpsLog -Level Information -Topic "rest" -Message "Writing comment to pull request"
                Write-AzOpsLog -Level Verbose -Topic "rest" -Message "Uri: $global:GitHubComments"
                $params = @{
                    Headers = @{
                        "Authorization" = ("Bearer " + $global:GitHubToken)
                    }
                    Body    = (@{
                            "body" = "$(Get-Content -Path "$PSScriptRoot/../auxiliary/guidance/strict/README.md" -Raw) `n Changes: `n`n$output"
                        } | ConvertTo-Json)
                }
                Invoke-RestMethod -Method "POST" -Uri $global:GitHubComments @params | Out-Null
                exit 1
            }
            if ($global:AzOpsStrictMode -eq 0) {
                Write-AzOpsLog -Level Warning -Topic "git" -Message "Default Mode"
                Write-AzOpsLog -Level Information -Topic "git" -Message "Changes:"
                Write-AzOpsLog -Level Information -Topic "rest" -Message "Writing comment to pull request"
                Write-AzOpsLog -Level Verbose -Topic "rest" -Message "Uri: $global:GitHubComments"
                $params = @{
                    Headers = @{
                        "Authorization" = ("Bearer " + $global:GitHubToken)
                    }
                    Body    = (@{
                            "body" = "$(Get-Content -Path "$PSScriptRoot/../auxiliary/guidance/default/README.md" -Raw) `n Changes: `n`n$output"
                        } | ConvertTo-Json)
                }
                Invoke-RestMethod -Method "POST" -Uri $global:GitHubComments @params | Out-Null
            }
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Branch is consistent with Azure"
        }
    }

    process {
        Write-AzOpsLog -Level Information -Topic "git" -Message "Pulling latest changes"
        Start-AzOpsNativeExecution {
            git pull
        } | Out-Host

        # Changes
        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking for additions / modifications / deletions"
        $changeSet = @()
        $changeSet = Start-AzOpsNativeExecution {
            git diff origin/main --ignore-space-at-eol --name-status
        }

        if (!$changeSet) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "No changes detected"
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Iterating through changes"
        }

        $deleteSet = @()
        $addModifySet = @()
        foreach ($change in $changeSet) {
            $filename = ($change -split "`t")[-1]
            if (($change -split "`t" | Select-Object -first 1) -eq 'D') {
                $deleteSet += $filename
            }
            elseif (($change -split "`t" | Select-Object -first 1) -eq 'A' -or 'M' -or 'R') {
                $addModifySet += $filename
            }
        }

        Write-AzOpsLog -Level Information -Topic "git" -Message "Add / Modify:"
        $addModifySet | ForEach-Object {
            Write-AzOpsLog -Level Information -Topic "git" -Message $_
        }

        Write-AzOpsLog -Level Information -Topic "git" -Message "Delete:"
        $deleteSet | ForEach-Object {
            Write-AzOpsLog -Level Information -Topic "git" -Message $_
        }

        # Deployment
        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.subscription.json$' } `
        | Sort-Object -Property $_ `
        | ForEach-Object {
            Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.subscription.json"
            New-AzOpsStateDeployment -filename $_
        }

        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.providerfeatures.json$' } `
        | Sort-Object -Property $_ `
        | ForEach-Object {
            Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.providerfeatures.json"
            New-AzOpsStateDeployment -filename $_
        }


        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.resourceproviders.json$' } `
        | Sort-Object -Property $_ `
        | ForEach-Object {
            Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.resourceproviders.json"
            New-AzOpsStateDeployment -filename $_
        }

        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.parameters.json$' } `
        | Sort-Object -Property $_ `
        | Foreach-Object {
            Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.parameters.json"
            New-AzOpsStateDeployment -filename $_
        }
    }

    end {
        Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking post refresh process"

        Write-AzOpsLog -Level Information -Topic "git" -Message "Fetching latest origin changes"
        Start-AzOpsNativeExecution {
            git fetch origin
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Checking out existing local branch ($global:GitHubHeadRef)"
        Start-AzOpsNativeExecution {
            git checkout $global:GitHubHeadRef
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Pulling origin branch ($global:GitHubHeadRef) changes"
        Start-AzOpsNativeExecution {
            git pull origin $global:GitHubHeadRef
        } | Out-Host

        Write-AzOpsLog -Level Information -Topic "git" -Message "Merging origin branch ($global:GitHubBaseRef) changes"
        Start-AzOpsNativeExecution {
            git merge origin/$global:GitHubHeadRef --no-commit
        } | Out-Host

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
            Write-AzOpsLog -Level Information -Topic "git" -Message "Creating new commit"
            Start-AzOpsNativeExecution {
                git commit -m 'System commit'
            } | Out-Host

            Write-AzOpsLog -Level Information -Topic "git" -Message "Pushing new changes to origin ($global:GitHubHeadRef)"
            Start-AzOpsNativeExecution {
                git push origin $global:GitHubHeadRef
            } | Out-Host
        }
    }

}