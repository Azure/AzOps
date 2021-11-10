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
        $ResultSizeLimit = "64000"
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile'

        if (-not (Test-Path -Path '/tmp/OUTPUT.md')) {
            New-Item -Path '/tmp/OUTPUT.md'
            New-Item -Path '/tmp/OUTPUT.json'
        }

        if ($RemoveAzOpsFlag) {
            $mdOutput = '{0}WhatIf Results: Resource Deletion:{1}{0}' -f [environment]::NewLine, $Results
        }
        else {
            $resultJson = ($Results.Changes | ConvertTo-Json -Depth 100)
            $resultString = $Results | Out-String
            $resultStringMeasure = $resultString | Measure-Object -Line -Character -Word
            if ($($resultStringMeasure.Characters) -gt $ResultSizeLimit) {
                $mdOutput = 'WhatIf Results: WhatIf is too large for comment field, for more details look at PR files to determine changes.'
            }
            else {
                $mdOutput = 'WhatIf Results: Resource Creation:{0}```{0}{1}{0}```{0}' -f [environment]::NewLine, $resultString
            }
            Add-Content -Path '/tmp/OUTPUT.json' -Value $resultJson -WhatIf:$false
        }
        Add-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
    }
}