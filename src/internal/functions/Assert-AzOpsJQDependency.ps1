function Assert-AzOpsJQDependency {

    <#
        .SYNOPSIS
            Asserts that - if jq is installed and in current path
        .DESCRIPTION
            Asserts that - if jq is installed and in current path
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Assert-AzOpsJQDependency -Cmdlet $PSCmdlet
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $Cmdlet
    )

    process {

        Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJQDependency.Validating'

        $result = (Invoke-AzOpsNativeCommand -ScriptBlock { jq --version } -IgnoreExitcode) -as [bool]

        if ($result) {
            Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJQDependency.Success'
            return
        }

        $exception = [System.InvalidOperationException]::new('JQ is not in current path')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-PSFMessage -Level Warning -String 'Assert-AzOpsJQDependency.Failed' -Tag error
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}