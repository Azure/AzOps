function Assert-AzOpsInitialization {

    <#
        .SYNOPSIS
            Asserts AzOps has been correctly prepare for execution.
        .DESCRIPTION
            Asserts AzOps has been correctly prepare for execution.
            This boils down to Initialize-AzOpsEnvironment having been executed successfully.
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .PARAMETER StatePath
            Path to where the AzOps processing state / repository is located at.
        .EXAMPLE
            > Assert-AzOpsInitialization -Cmdlet $PSCmdlet -Statepath $StatePath
            Asserts AzOps has been correctly prepare for execution.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [string]
        $StatePath
    )

    begin {
        $strings = Get-PSFLocalizedString -Module AzOps
        $invalidPathPattern = [System.IO.Path]::GetInvalidPathChars() -replace '\|', '\|' -join "|"
    }

    process {
        $stateGood = $StatePath -and $StatePath -notmatch $invalidPathPattern
        if (-not $stateGood) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsInitialization.StateError'
            $exception = [System.InvalidOperationException]::new($strings.'Assert-AzOpsInitialization.StateError')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "BadData", 'InvalidData', $null)
        }
        $cacheBuilt = $script:AzOpsSubscriptions -or $script:AzOpsAzManagementGroup
        if (-not $cacheBuilt) {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Assert-AzOpsInitialization.NoCache'
            $exception = [System.InvalidOperationException]::new($strings.'Assert-AzOpsInitialization.NoCache')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "NoCache", 'InvalidData', $null)
        }

        if (-not $stateGood -or -not $cacheBuilt) {
            $Cmdlet.ThrowTerminatingError($errorRecord)
        }
    }

}