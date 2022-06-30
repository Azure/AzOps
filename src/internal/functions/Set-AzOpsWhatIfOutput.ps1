﻿function Set-AzOpsWhatIfOutput {

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
        .PARAMETER StatePath
            File in scope of WhatIf
        .EXAMPLE
            > Set-AzOpsWhatIfOutput -Results $results
            > Set-AzOpsWhatIfOutput -Results $results -RemoveAzOpsFlag $true
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

        [Parameter(Mandatory = $false)]
        $StatePath
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile'
        if (-not (Test-Path -Path '/tmp/OUTPUT.md')) {
            New-Item -Path '/tmp/OUTPUT.md' -WhatIf:$false
            New-Item -Path '/tmp/OUTPUT.json' -WhatIf:$false
        }
        if ($StatePath -match '/') {
            $StatePath = ($StatePath -split '/')[-1]
        }
        # Measure input $Results.Changes content
        $resultJson = ($Results.Changes | ConvertTo-Json -Depth 100)
        $resultString = $Results | Out-String
        $resultStringMeasure = $resultString | Measure-Object -Line -Character -Word
        # Measure current /tmp/OUTPUT.md content
        $existingContentMd = Get-Content -Path '/tmp/OUTPUT.md' -Raw
        $existingContentStringMd = $existingContentMd | Out-String
        $existingContentStringMeasureMd = $existingContentStringMd | Measure-Object -Line -Character -Word
        # Gather current /tmp/OUTPUT.json content
        $existingContent = @(Get-Content -Path '/tmp/OUTPUT.json' -Raw | ConvertFrom-Json -Depth 100)
        # Check if $existingContentStringMeasureMd and $resultStringMeasure exceed allowed size in $ResultSizeLimit
        if (($existingContentStringMeasureMd.Characters + $resultStringMeasure.Characters) -gt $ResultSizeLimit) {
            Write-PSFMessage -Level Warning -String 'Set-AzOpsWhatIfOutput.WhatIfFileMax' -StringValues $ResultSizeLimit
            $mdOutput = 'WhatIf Results for {1}:{0} WhatIf is too large for comment field, for more details look at PR files to determine changes.' -f [environment]::NewLine, $StatePath
        }
        else {
            if ($RemoveAzOpsFlag) {
                $mdOutput = '{0}WhatIf Results for Resource Deletion of {2}:{0}```{0}{1}{0}```' -f [environment]::NewLine, $Results, $StatePath
            }
            else {
                if ($existingContent.count -gt 0) {
                    $existingContent += $results.Changes
                    $existingContent = $existingContent | ConvertTo-Json -Depth 100
                }
                else {
                    $existingContent = $resultJson
                }
                $mdOutput = 'WhatIf Results for {2}:{0}```{0}{1}{0}```{0}' -f [environment]::NewLine, $resultString, $StatePath
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFileAddingJson'
                Set-Content -Path '/tmp/OUTPUT.json' -Value $existingContent -WhatIf:$false
            }
        }
        if ((($mdOutput | Measure-Object -Line -Character -Word).Characters + $existingContentStringMeasureMd.Characters) -le $ResultSizeMaxLimit) {
            Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFileAddingMd'
            Add-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
        }
        else {
            Write-PSFMessage -Level Warning -String 'Set-AzOpsWhatIfOutput.WhatIfMessageMax' -StringValues $ResultSizeMaxLimit
        }
    }
}