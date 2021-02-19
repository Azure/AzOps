function Invoke-NativeCommand {
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
        PS C:\> Invoke-NativeCommand -Scriptblock { git config --system -l }
    
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
    
    if (-not $Quiet) {
        $output = & $ScriptBlock 2>&1
    }
    else { $output = & $ScriptBlock }
    
    if ($LASTEXITCODE -ne 0 -and -not $IgnoreExitcode) {
        if (-not $Quiet -and $output) {
            $output | Out-String | ForEach-Object {
                Write-PSFMessage -Level Warning -Message $_
            }
        }
        
        $caller = Get-PSCallStack -ErrorAction SilentlyContinue
        if ($caller) {
            Stop-PSFFunction -String 'Invoke-NativeCommand.Failed.WithCallstack' -StringValues $ScriptBlock, $caller[1].ScriptName, $caller[1].ScriptLineNumber, $LASTEXITCODE -Cmdlet $PSCmdlet -EnableException $true
        }
        Stop-PSFFunction -String 'Invoke-NativeCommand.Failed.NoCallstack' -StringValues $ScriptBlock, $LASTEXITCODE -Cmdlet $PSCmdlet -EnableException $true
    }
    elseif ($output) { $output }
}