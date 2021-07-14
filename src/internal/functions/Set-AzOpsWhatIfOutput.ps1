function Set-AzOpsWhatIfOutput {

    <#
        .SYNOPSIS
            Logs the output from a What-If deployment
        .DESCRIPTION
            Logs the output from a What-If deployment
        .PARAMETER results
            The WhatIf result from a deployment
        .EXAMPLE
            > et-WhatIfOutput -results $results
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $results
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' 

        $resultJson=($results.Changes | ConvertTo-Json -Depth 5)
        $mdOutput = 'WhatIf Results:{0}```json{0}{1}{0}```{0}' -f [environment]::NewLine, $resultJson

        Set-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
        Set-Content -Path '/tmp/OUTPUT.json' -Value $resultJson -WhatIf:$false
    }

}