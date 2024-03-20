function Assert-AzOpsJqDependency {

    <#
        .SYNOPSIS
            Asserts that - if jq is installed and in current path
        .DESCRIPTION
            Asserts that - if jq is installed and in current path
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Assert-AzOpsJqDependency -Cmdlet $PSCmdlet
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Cmdlet
    )

    process {
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Assert-AzOpsJqDependency.Validating'
        $minVersion = New-Object System.Version("1.6")
        $result = (Invoke-AzOpsNativeCommand -ScriptBlock { jq --version } -IgnoreExitcode)
        $installed = $result -as [bool]

        if ($installed) {
            $version = New-Object System.Version(($result).Split("-")[1])
            if ($version -ge $minVersion) {
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Assert-AzOpsJqDependency.Success'
                return
            }
            else {
                $exception = [System.InvalidOperationException]::new('Unsupported version of jq installed. Please update to a minimum jq version of 1.6')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
                Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsJqDependency.Failed'
                $Cmdlet.ThrowTerminatingError($errorRecord)
            }
        }

        $exception = [System.InvalidOperationException]::new('Unable to locate jq installation')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsJqDependency.Failed'
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}