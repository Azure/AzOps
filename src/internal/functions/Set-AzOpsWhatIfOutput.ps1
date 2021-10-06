function Set-AzOpsWhatIfOutput {

    <#
        .SYNOPSIS
            Logs the output from a What-If deployment
        .DESCRIPTION
            Logs the output from a What-If deployment
        .PARAMETER results
            The WhatIf result from a deployment
        .EXAMPLE
            > Set-WhatIfOutput -results $results -removeAzOpsFlag $true
            $removeAzOpsFlag is set to true when we need to push contents for Remove-AzopsDeployment to PR
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $results,

        [Parameter(Mandatory = $false)]
        $removeAzOpsFlag = $false
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile'

        if (-not (Test-Path -Path '/tmp/OUTPUT.md')) {
            New-Item -Path '/tmp/OUTPUT.md'
            New-Item -Path '/tmp/OUTPUT.json'
        }

        if ($removeAzOpsFlag) {
            $mdOutput = '{0}WhatIf Results: Resource Deletion:{1}{0}' -f [environment]::NewLine, $results
        }
        else {
            $resultJson = ($results.Changes | ConvertTo-Json -Depth 100)
            $mdOutput = 'WhatIf Results: Resource Creation:{0}```json{0}{1}{0}```{0}' -f [environment]::NewLine, $resultJson
            Add-Content -Path '/tmp/OUTPUT.json' -Value $resultJson -WhatIf:$false
        }
        Add-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
    }
}