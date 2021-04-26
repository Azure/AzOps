﻿function Assert-AzOpsJqDependency {

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
        Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJqDependency.Validating'

        $result = (Invoke-AzOpsNativeCommand -ScriptBlock { jq --version } -IgnoreExitcode)
        $installed = $result -as [bool]

        if ($installed) {
            [double]$version = ($result).Split("-")[1]
            if ($version -ge 1.6) {
                Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJqDependency.Success'
                return
            }
            else {
                $exception = [System.InvalidOperationException]::new('Unsupported version of jq installed. Please update to a minimum jq version of 1.6')
                $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
                Write-PSFMessage -Level Warning -String 'Assert-AzOpsJqDependency.Failed' -Tag error
                $Cmdlet.ThrowTerminatingError($errorRecord)
            }
        }

        $exception = [System.InvalidOperationException]::new('Unable to locate jq installation')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-PSFMessage -Level Warning -String 'Assert-AzOpsJqDependency.Failed' -Tag error
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}