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
        Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsBicepDependency.Validating'

        $result = (Invoke-AzOpsNativeCommand -ScriptBlock { bicep --version } -IgnoreExitcode)
        $installed = $result -as [bool]

        if ($installed) {
            Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsBicepDependency.Success'
        }
        else {
            $exception = [System.InvalidOperationException]::new('Unable to locate bicep installation')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
            Write-PSFMessage -Level Warning -String 'Assert-AzOpsBicepDependency.NotFound' -Tag error
            $Cmdlet.ThrowTerminatingError($errorRecord)
        }

    }

}