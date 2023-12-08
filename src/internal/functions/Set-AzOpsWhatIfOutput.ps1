function Set-AzOpsWhatIfOutput {

    <#
        .SYNOPSIS
            Logs the output from a What-If deployment
        .DESCRIPTION
            Logs the output from a What-If deployment
        .PARAMETER Results
            The WhatIf result from a deployment
        .PARAMETER RemoveAzOpsFlag
            RemoveAzOpsFlag is set to true when a need to push content about deletion is required
        .PARAMETER ResultSizeLimit
            The character limit allowed for comments 64,000
        .PARAMETER ResultSizeMaxLimit
            The maximum upper character limit allowed for comments 64,600
        .PARAMETER FilePath
            Template File in scope of WhatIf
        .PARAMETER ParameterFilePath
            Parameter File in scope of WhatIf
        .EXAMPLE
            > Set-AzOpsWhatIfOutput -Results $results
            > Set-AzOpsWhatIfOutput -Results $results -RemoveAzOpsFlag $true
            > Set-AzOpsWhatIfOutput -FilePath '/templates/root/myresource.bicep' -Results $results -RemoveAzOpsFlag $true
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Results,

        [Parameter(Mandatory = $false)]
        $RemoveAzOpsFlag = $false,

        [Parameter(Mandatory = $false)]
        $ResultSizeLimit = "64000",

        [Parameter(Mandatory = $false)]
        $ResultSizeMaxLimit = "64600",

        [Parameter(Mandatory = $true)]
        $FilePath,

        [Parameter(Mandatory = $false)]
        $ParameterFilePath
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile'
        $tempPath = [System.IO.Path]::GetTempPath()
        if ((-not (Test-Path -Path ($tempPath + 'OUTPUT.md'))) -or (-not (Test-Path -Path ($tempPath + 'OUTPUT.json')))) {
            New-Item -Path ($tempPath + 'OUTPUT.md') -WhatIf:$false
            New-Item -Path ($tempPath + 'OUTPUT.json') -WhatIf:$false
        }

        if ($ParameterFilePath) {
            $resultHeadline = "$($FilePath.split([System.IO.Path]::DirectorySeparatorChar)[-1]) with $($ParameterFilePath.split([System.IO.Path]::DirectorySeparatorChar)[-1])"
        }
        else {
            $resultHeadline = $resultHeadline = $FilePath.split([System.IO.Path]::DirectorySeparatorChar)[-1]
        }

        # Measure input $Results.Changes content
        $resultString = $Results | Out-String
        $resultStringMeasure = $resultString | Measure-Object -Line -Character -Word
        # Measure current OUTPUT.md content
        $existingContentMd = Get-Content -Path ($tempPath + 'OUTPUT.md') -Raw
        $existingContentStringMd = $existingContentMd | Out-String
        $existingContentStringMeasureMd = $existingContentStringMd | Measure-Object -Line -Character -Word
        # Gather current OUTPUT.json content
        $existingContent = @(Get-Content -Path ($tempPath + 'OUTPUT.json') -Raw | ConvertFrom-Json -Depth 100)
        # Export results to json file
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFileAddingJson'
        if ($RemoveAzOpsFlag) {
            $resultJson = [PSCustomObject]@{
                WhatIfResult = $Results
                TemplateFile = $resultHeadline
            }
        }
        else {
            $resultJson = $results.Changes
            $resultJson | Add-Member -Name "TemplateFile" -Value $resultHeadline -MemberType NoteProperty -Force
        }
        $existingContent += $resultJson
        $existingContent = $existingContent | ConvertTo-Json -Depth 100
        Set-Content -Path ($tempPath + 'OUTPUT.json') -Value $existingContent -WhatIf:$false
        # Check if $existingContentStringMeasureMd and $resultStringMeasure exceed allowed size in $ResultSizeLimit
        if (($existingContentStringMeasureMd.Characters + $resultStringMeasure.Characters) -gt $ResultSizeLimit) {
            Write-PSFMessage -Level Warning -String 'Set-AzOpsWhatIfOutput.WhatIfFileMax' -StringValues $ResultSizeLimit
            $mdOutput = 'WhatIf Results for {1}:{0} WhatIf is too large for comment field, for more details look at PR files to determine changes.' -f [environment]::NewLine, $resultHeadline
        }
        else {
            if ($RemoveAzOpsFlag) {
                if ($Results -match 'Missing resource dependency' ) {
                    $mdOutput = ':x: **Action Required**{0}WhatIf Results for Resource Deletion of {2}:{0}```{0}{1}{0}```' -f [environment]::NewLine, $Results, $resultHeadline
                }
                elseif ($Results -match 'What if operation failed') {
                    $mdOutput = ':warning: WhatIf Results for Resource Deletion of {2}:{0}```{0}{1}{0}```' -f [environment]::NewLine, $Results, $resultHeadline
                }
                else {
                    $mdOutput = ':white_check_mark: WhatIf Results for Resource Deletion of {2}:{0}```{0}{1}{0}```' -f [environment]::NewLine, $Results, $resultHeadline
                }
            }
            else {
                $mdOutput = 'WhatIf Results for {2}:{0}```{0}{1}{0}```{0}' -f [environment]::NewLine, $resultString, $resultHeadline
            }
        }
        if ((($mdOutput | Measure-Object -Line -Character -Word).Characters + $existingContentStringMeasureMd.Characters) -le $ResultSizeMaxLimit) {
            Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFileAddingMd'
            Add-Content -Path ($tempPath + 'OUTPUT.md') -Value $mdOutput -WhatIf:$false
        }
        else {
            Write-PSFMessage -Level Warning -String 'Set-AzOpsWhatIfOutput.WhatIfMessageMax' -StringValues $ResultSizeMaxLimit
        }
    }
}