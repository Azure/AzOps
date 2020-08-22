<#
.SYNOPSIS
    This cmdlet processes AzOps changes.
.DESCRIPTION

    Invoke-AzOpsChange -changeset [filenames]
.INPUTS
    Array of Filename
.OUTPUTS
    None
#>
function Invoke-AzOpsChange {

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsDefaultDeploymentRegion')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsMainTemplate')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$changeSet
    )
    begin {}

    process {
        if ($changeSet) {
            Write-AzOpsLog -Level Information -Topic "git" -Message "Deployment required"
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

            $addModifySet `
            | Where-Object -FilterScript { $_ -match '/*.subscription.json$' } `
            | Sort-Object -Property $_ `
            | ForEach-Object {
                Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.subscription.json for a file $_"
                New-AzOpsStateDeployment -filename $_
            }

            $addModifySet `
            | Where-Object -FilterScript { $_ -match '/*.providerfeatures.json$' } `
            | Sort-Object -Property $_ `
            | ForEach-Object {
                Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.providerfeatures.json for a file $_"
                New-AzOpsStateDeployment -filename $_
            }

            $addModifySet `
            | Where-Object -FilterScript { $_ -match '/*.resourceproviders.json$' } `
            | Sort-Object -Property $_ `
            | ForEach-Object {
                Write-AzOpsLog -Level Information -Topic "Invoke-AzOpsGitPush" -Message "Invoking new state deployment - *.resourceproviders.json for a file $_"
                New-AzOpsStateDeployment -filename $_
            }

            $AzOpsDeploymentList = @()
            $addModifySet `
            | Sort-Object -Property $_ `
            | Where-Object -FilterScript { $_ -match ((get-item $Global:AzOpsState).Name) } `
            | Foreach-Object {
                $scope = (New-AzOpsScope -path $_)
                if ($scope) {
                    $templateFilePath = $null
                    $templateParameterFilePath = $null
                    $deploymentName = $null
                    #Find the template
                    if ($_.EndsWith('.parameters.json')) {
                        $templateParameterFilePath = (Get-Item $_).FullName

                        if (Test-Path (Get-Item $_).FullName.Replace('.parameters.json', '.json')) {
                            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Template found $(($(Get-Item $_).FullName.Replace('.parameters.json', '.json')))"
                            $templateFilePath = (Get-Item $_).FullName.Replace('.parameters.json', '.json')
                        }
                        else {
                            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Template NOT found $(($(Get-Item $_).FullName.Replace('.parameters.json', '.json')))"
                            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Determining resource type $((Get-Item $global:AzOpsMainTemplate).FullName)"
                            # Determine Resource Type in Parameter file
                            $templateParameterFileHashtable = Get-Content ($_) | ConvertFrom-Json -AsHashtable
                            $effectiveResourceType = $null
                            if (
                                ($null -ne $templateParameterFileHashtable) -and
                                ($templateParameterFileHashtable.Keys -contains "`$schema") -and
                                ($templateParameterFileHashtable.Keys -contains "parameters") -and
                                ($templateParameterFileHashtable.parameters.Keys -contains "input")
                            ) {
                                if ($templateParameterFileHashtable.parameters.input.value.Keys -contains "Type") {
                                    # ManagementGroup and Subscription
                                    $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.Type
                                }
                                elseif ($templateParameterFileHashtable.parameters.input.value.Keys -contains "ResourceType") {
                                    # Resource
                                    $effectiveResourceType = $templateParameterFileHashtable.parameters.input.value.ResourceType
                                }
                            }
                            # Check if generic template is supporting the resource type for the deployment.
                            if ($effectiveResourceType -and
                                ((Get-Content (Get-Item $global:AzOpsMainTemplate).FullName) | ConvertFrom-Json -AsHashtable).variables.apiVersionLookup.Keys -icontains $effectiveResourceType) {
                                Write-AzOpsLog -Level Information -Topic "pwsh" -Message "effectiveResourceType: $effectiveResourceType AzOpsMainTemplate supports resource type $effectiveResourceType in $((Get-Item $global:AzOpsMainTemplate).FullName)"
                                $templateFilePath = (Get-Item $global:AzOpsMainTemplate).FullName
                            }
                            else {
                                Write-AzOpsLog -Level Warning -Topic "pwsh" -Message "effectiveResourceType: $effectiveResourceType AzOpsMainTemplate does NOT supports resource type $effectiveResourceType in $((Get-Item $global:AzOpsMainTemplate).FullName). Deployment will be ignored"
                            }
                        }
                    }
                    #Find the template parameter file
                    elseif ($_.EndsWith('.json')) {
                        $templateFilePath = (Get-Item $_).FullName
                        if (Test-Path (Get-Item $_).FullName.Replace('.json', '.parameters.json')) {
                            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Template Parameter found $(($(Get-Item $_).FullName.Replace('.json', '.parameters.json')))"
                            $templateParameterFilePath = (Get-Item $_).FullName.Replace('.json', '.parameters.json')
                        }
                        else {
                            Write-AzOpsLog -Level Information -Topic "pwsh" -Message "Template Parameter NOT found $(($(Get-Item $_).FullName.Replace('.json', '.parameters.json')))"
                        }
                    }
                    #Deployment Name
                    if ($null -ne $templateParameterFilePath) {
                        $deploymentName = (Get-Item $templateParameterFilePath).BaseName.replace('.parameters', '').Replace(' ', '_')
                    }
                    elseif ($null -ne $templateFilePath) {
                        $deploymentName = (Get-Item $templateFilePath).BaseName.replace('.json', '').Replace(' ', '_')
                    }
                    $deploymentName = 'AzOps-' + $deploymentName.SubString(0, ($deploymentName.Length -gt 58 )?58:$deploymentName.Length)
                    #construct deployment object
                    $AzOpsDeploymentList += [PSCustomObject] @{
                        [string] 'templateFilePath'          = $templateFilePath
                        [string] 'templateParameterFilePath' = $templateParameterFilePath
                        [string] 'deploymentName'            = $deploymentName
                        [string] 'scope'                     = $scope.scope
                    }
                    #New-AzOpsDeployment -templateFilePath $templateFilePath -templateParameterFilePath $templateParameterFilePath
                }
                else {
                    Write-AzOpsLog -Level Information -Topic "pwsh" -Message "$_ is not under $($Global:AzOpsState) and ignored for the deployment"
                }
            }
            #Starting Tenant Deployment
            $AzOpsDeploymentList `
            | Where-Object -FilterScript { $null -ne $_.templateFilePath } `
            | Select-Object  scope, deploymentName, templateFilePath, templateParameterFilePath -Unique `
            | Sort-Object -Property templateParameterFilePath `
            | ForEach-Object {
                New-AzOpsDeployment -templateFilePath $_.templateFilePath `
                                    -templateParameterFilePath  ($_.templateParameterFilePath ? $_.templateParameterFilePath : $null) `
                                    -deploymentName $_.deploymentName
            }
        }
    }
    end {}
}