function Set-AzOpsWhatIfOutput {

    <#
        .SYNOPSIS
            Logs the output from a What-If deployment
        .DESCRIPTION
            Logs the output from a What-If deployment
        .PARAMETER results
            The WhatIf result from a deployment
        .EXAMPLE
            > Set-AzOpsWhatIfOutput -results $results -removeAzOpsFlag $true
            $removeAzOpsFlag is set to true when we need to push contents for Remove-AzopsDeployment to PR
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
        $TemplatePath
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile'

        if (-not (Test-Path -Path '/tmp/OUTPUT.md')) {
            New-Item -Path '/tmp/OUTPUT.md' -WhatIf:$false
            New-Item -Path '/tmp/OUTPUT.json' -WhatIf:$false
        }

        if ($RemoveAzOpsFlag) {
            $mdOutput = '{0}WhatIf Results: Resource Deletion:{1}{0}' -f [environment]::NewLine, $Results
        }
        else {
            $resultJson = ($Results.Changes | ConvertTo-Json -Depth 100)
            $resultString = $Results | Out-String
            $resultStringMeasure = $resultString | Measure-Object -Line -Character -Word
            if ($($resultStringMeasure.Characters) -gt $ResultSizeLimit) {
                $mdOutput = 'WhatIf Results for {1}:{0} WhatIf is too large for comment field, for more details look at PR files to determine changes.' -f [environment]::NewLine, $TemplatePath
            }
            else {
                $mdOutput = 'WhatIf Results for {2}:{0}```{0}{1}{0}```{0}' -f [environment]::NewLine, $resultString, $TemplatePath
            }
            $existingContent = @(Get-Content -Path '/tmp/OUTPUT.json' -Raw | ConvertFrom-Json)
            if ($existingContent.count -gt 0) {
                $existingContent += $results.Changes
                $existingContent = $existingContent | ConvertTo-Json -Depth 100
            }
            else {
                $existingContent = $resultJson
            }
            Set-Content -Path '/tmp/OUTPUT.json' -Value $existingContent -WhatIf:$false
        }
        Add-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
    }
}