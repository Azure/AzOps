function Invoke-ScriptBlock {

    <#
        .SYNOPSIS
            Execute a scriptblock, retry if it fails.
        .DESCRIPTION
            Execute a scriptblock, retry if it fails.
        .PARAMETER ScriptBlock
            The scriptblock to execute.
        .PARAMETER ArgumentList
            Any arguments to pass to the scriptblock.
        .PARAMETER RetryCount
            How often to try again before giving up.
            Default: 0
        .PARAMETER RetryWait
            How long to wait between retries in seconds.
            Default: 3
        .PARAMETER RetryType
            How to wait for a retry?
            Either always the exact time specified in RetryWait as seconds, or exponentially increase the time between waits.
            Assuming a wait time of 2 seconds and three retries, this will result in the following waits between attempts:
            Linear (default): 2, 2, 2
            Exponential: 2, 4, 8
        .EXAMPLE
            PS C:\> Invoke-ScriptBlock -ScriptBlock { 1 / 0 }
            Will attempt once to divide by zero.
            Hint: This is unlikely to succeede. Ever.
        .EXAMPLE
            PS C:\> Invoke-ScriptBlock -ScriptBlock { 1 / 0 } -RetryCount 3
            Will attempt to divide by zero, retrying up to 3 additional times (for a total of 4 attempts).
            Hint: Trying to divide by zero more than once does not increase your chance of success.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock,

        [object[]]
        $ArgumentList,

        [int]
        $RetryCount = 0,

        [int]
        $RetryWait = 3,

        [ValidateSet('Linear','Exponential')]
        [string]
        $RetryType = 'Linear'
    )

    begin {
        $count = 0
    }

    process {
        while ($count -le $RetryCount) {
            try {
                if (Test-PSFParameterBinding -ParameterName ArgumentList) { & $ScriptBlock $ArgumentList }
                else { & $ScriptBlock }
                break
            }
            catch {
                if ($count -lt $RetryCount) {
                    Write-PSFMessage -Level Debug -String 'Invoke-ScriptBlock.Failed.WillRetry' -StringValues $count, $RetryCount -ErrorRecord $_
                    $count++
                    switch ($RetryType) {
                        Linear { Start-Sleep -Seconds $RetryWait }
                        Exponential { Start-Sleep -Seconds ([math]::Pow($RetryWait, $count)) }
                    }
                    continue
                }
                Write-PSFMessage -Level Warning -String 'Invoke-ScriptBlock.Failed.GivingUp' -StringValues $count, $RetryCount -ErrorRecord $_
                throw
            }
        }
    }

}