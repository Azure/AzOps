function Invoke-AzOpsNativeCommand {

    <#
        .SYNOPSIS
            Executes a native command.
        .DESCRIPTION
            Executes a native command.
        .PARAMETER ScriptBlock
            The scriptblock containing the native command to execute.
            Note: Specifying a scriptblock WITHOUT any native command may cause erroneous LASTEXITCODE detection.
        .PARAMETER IgnoreExitcode
            Whether to ignore exitcodes.
        .PARAMETER Quiet
            Quiet mode disables printing error output of a native command.
        .EXAMPLE
            > Invoke-AzOpsNativeCommand -Scriptblock { git config --system -l }
            Executes "git config --system -l"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [switch]
        $IgnoreExitcode,

        [switch]
        $Quiet
    )

    try {
        if ($Quiet) {
            $output = & $ScriptBlock 2>&1
        }
        else { $output = & $ScriptBlock }

        if (-not $Quiet -and $output) {
            $output | Out-String -NoNewLine | ForEach-Object {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Invoke-AzOpsNativeCommand' -LogStringValues $ScriptBlock, $_
            }
            $output
        }
    }
    catch {
        if (-not $IgnoreExitcode) {
            $caller = Get-PSCallStack -ErrorAction SilentlyContinue
            if ($caller) {
                Stop-PSFFunction -String 'Invoke-AzOpsNativeCommand.Failed.WithCallstack' -StringValues $ScriptBlock, $caller[1].ScriptName, $caller[1].ScriptLineNumber, $LASTEXITCODE -Cmdlet $PSCmdlet -EnableException $true
            }
            Stop-PSFFunction -String 'Invoke-AzOpsNativeCommand.Failed.NoCallstack' -StringValues $ScriptBlock, $LASTEXITCODE -Cmdlet $PSCmdlet -EnableException $true
        }
        $output
    }
}