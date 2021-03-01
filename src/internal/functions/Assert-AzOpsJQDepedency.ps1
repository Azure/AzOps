function Assert-AzOpsJQDepedency {

    <#
        .SYNOPSIS
            Asserts that - if jq is installed and in current path
        .DESCRIPTION
            Asserts that - if jq is installed and in current path
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Assert-AzOpsJQDepedency -Cmdlet $PSCmdlet
    #>

    [CmdletBinding()]
    param (
    )

    process {

        Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJQDepedency.Validating'

        $result = Invoke-AzOpsScriptBlock -ScriptBlock {jq -n} -RetryCount:0 -ErrorAction:SilentlyContinue

        if($result)
        {
            Write-PSFMessage -Level InternalComment -String 'Assert-AzOpsJQDepedency.Success'
            return
        }

        $exception = [System.InvalidOperationException]::new('JQ is not in current path')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
        Write-PSFMessage -Level Warning -String 'Assert-AzOpsJQDepedency.Failed' -Tag error
        $Cmdlet.ThrowTerminatingError($errorRecord)
    }

}