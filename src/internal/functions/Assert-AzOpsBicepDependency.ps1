function Assert-AzOpsBicepDependency {

    <#
        .SYNOPSIS
            Asserts that - if bicep is installed and in current path
        .DESCRIPTION
            Asserts that - if bicep is installed and in current path
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Cmdlet
    )

    process {
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Assert-AzOpsBicepDependency.Validating'

        $result = (Invoke-AzOpsNativeCommand -ScriptBlock { bicep --version } -IgnoreExitcode)
        $installed = $result -as [bool]

        if ($installed) {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Assert-AzOpsBicepDependency.Success'
        }
        else {
            $exception = [System.InvalidOperationException]::new('Unable to locate bicep installation')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
            Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsBicepDependency.NotFound'
            $Cmdlet.ThrowTerminatingError($errorRecord)
        }

    }

}