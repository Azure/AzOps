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
            Write-PSFMessage -Level Warning -String 'Assert-AzOpsBicepDependency.NotFound'
        }

    }

}