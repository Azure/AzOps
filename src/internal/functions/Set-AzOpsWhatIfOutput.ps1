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
        $Results,

        [Parameter(Mandatory = $false)]
        $RemoveAzOpsFlag = $false
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
            $resultJson = ($results.Changes | ConvertTo-Json -Depth 100)
            $mdOutput = 'WhatIf Results: Resource Creation:{0}```json{0}{1}{0}```{0}' -f [environment]::NewLine, $resultJson
            #If there is existing content in output.json we want to preserve that and append to it the latest results in a proper JSON document
            #with a top level array for parsing later if needed.
            $existingContent = @(get-content '/tmp/OUTPUT.json' -raw | convertfrom-json)
            if($existingContent.count -gt 0){
                $existingContent+=$results.Changes
                $existingContent=$existingContent|ConvertTo-Json -Depth 100
            }
            else{$existingContent=$resultJson}
            Set-Content -Path '/tmp/OUTPUT.json' -Value $existingContent -WhatIf:$false
        }
        Add-Content -Path '/tmp/OUTPUT.md' -Value $mdOutput -WhatIf:$false
    }
}