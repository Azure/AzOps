function Invoke-AzOpsGitPush {

    [CmdletBinding()]
    [OutputType()]
    param ()

    begin {
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking pre refresh process"
        $diff = Invoke-AzOpsGitPushRefresh -Operation "Before" -BaseBranch $env:INPUT_GITHUB_BASE_REF -HeadBranch $env:INPUT_GITHUB_HEAD_REF
        
        # Messages

        if ($null -ne $diff) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Branch is out of sync with Azure"
            
            Write-AzOpsLog -Level Information -Topic "git" -Message "Changes:"
            $output = @()
            $diff.Split(",") | ForEach-Object { 
                $output += ( "``" + $_ + "``")
                $output += "`n"
                Write-AzOpsLog -Level Information -Topic "git" -Message $_
            }

            Write-AzOpsLog -Level Information -Topic "rest" -Message "Writing comment to pull request"

            switch ($env:INPUT_SCMPLATFORM) {
                "GitHub" {
                    Write-AzOpsLog -Level Verbose -Topic "rest" -Message "Uri: $env:INPUT_GITHUB_COMMENTS"
                    $params = @{
                        Headers = @{
                            "Authorization" = ("Bearer " + $env:GITHUB_TOKEN )
                        }
                        Body    = (@{
                                "body" = "$(Get-Content -Path "$PSScriptRoot/../Comments.md" -Raw) `n Changes: `n`n$output"
                            } | ConvertTo-Json)
                    }
                    Invoke-RestMethod -Method "POST" -Uri $env:INPUT_GITHUB_COMMENTS @params
                    exit 1
                }
                "AzureDevOps" {
                    Write-AzOpsLog -Level Verbose -Topic "rest" -Message "Uri: $env:INPUT_ADO_COMMENTS"
                    $params = @{
                        Uri     = "$($env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI)$($env:SYSTEM_TEAMPROJECTID)/_apis/git/repositories/$($env:BUILD_REPOSITORY_ID)/pullRequests/$($env:SYSTEM_PULLREQUEST_PULLREQUESTID)/threads?api-version=5.1"
                        Method  = "Post"
                        Headers = @{
                            "Authorization" = ("Bearer " + $env:SYSTEM_ACCESSTOKEN)
                            "Content-Type"  = "application/json"
                        }
                        Body    = (@{
                                comments = @(
                                    (@{
                                            "parentCommentId" = 0
                                            "content"         = "$(Get-Content -Path "$PSScriptRoot/../Comments.md" -Raw)"
                                            "commentType"     = 1
                                        })
                                )
                            }  | ConvertTo-Json -Depth 5)
                    }
                    Invoke-RestMethod @params -Verbose:$VerbosePreference
                    exit 1
                }
                Default {
                    Write-AzOpsLog -Level Error -Topic "rest" -Message "Could not determine SCM platform from INPUT_SCMPLATFORM. Current value is $env:INPUT_SCMPLATFORM"
                }
            }
        }
        else {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Branch is in sync with Azure"
        }

        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Initializing global variables"
        Initialize-AzOpsGlobalVariables
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
            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking new state deployment - *.subscription.json"
            New-AzOpsStateDeployment -filename $_ 
        }
        
        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.providerfeatures.json$' } `
        | Sort-Object -Property $_ `
        | ForEach-Object { 
            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking new state deployment - *.providerfeatures.json"
            New-AzOpsStateDeployment -filename $_ 
        }
        
        
        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.resourceproviders.json$' } `
        | Sort-Object -Property $_ `
        | ForEach-Object { 
            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking new state deployment - *.resourceproviders.json"
            New-AzOpsStateDeployment -filename $_ 
        }
        
        $addModifySet `
        | Where-Object -FilterScript { $_ -match '/*.parameters.json$' } `
        | Sort-Object -Property $_ `
        | Foreach-Object { 
            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking new state deployment - *.parameters.json"
            New-AzOpsStateDeployment -filename $_ 
        }
    }

    end {
        Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Invoking post refresh process"
        Invoke-AzOpsGitPushRefresh -Operation "After" -BaseBranch $env:INPUT_GITHUB_BASE_REF -HeadBranch $env:INPUT_GITHUB_HEAD_REF

        # Write-AzOpsLog -Level Information -Topic "rest" -Message "Checking if issue comment exists"
        # $params = @{
        #     Uri     = ($env:INPUT_GITHUB_ISSUE + "/comments")
        #     Headers = @{
        #         "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
        #     }
        # }
        # $response = Invoke-RestMethod -Method "Get" @params | Where-Object -FilterScript { $_.user.login -eq "github-actions[bot]" }

        # Write-AzOpsLog -Level Information -Topic "rest" -Message "Removing system comment"
        # if ($response) {
        #     $params = @{
        #         Uri     = ($env:INPUT_GITHUB_ISSUE + "/comments/" + $response.id)
        #         Headers = @{
        #             "Authorization" = ("Bearer " + $env:GITHUB_TOKEN)
        #         }
        #     }
        #     $response = Invoke-RestMethod -Method "Delete" @params
        # }
        
    }

}