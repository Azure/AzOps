function Assert-WindowsLongPath {
<#
	.SYNOPSIS
		Asserts that - if on windows - long paths have been enabled.
	
	.DESCRIPTION
		Asserts that - if on windows - long paths have been enabled.
	
	.PARAMETER Cmdlet
		The $PSCmdlet variable of the calling command.
	
	.EXAMPLE
		PS C:\> Assert-WindowsLongPath -Cmdlet $PSCmdlet
	
		Asserts that - if on windows - long paths have been enabled.
#>
	[Alias('Test-AzOpsRuntime')]
	[CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Cmdlet
    )

    process
    {
        # Of no interest outside of windows
        if (-not $IsWindows) { return }

        Write-PSFMessage -Level InternalComment -String 'Assert-WindowsLongPath.Validating'
        
        $hasRegKey = 1 -eq (Get-ItemPropertyValue -Path HKLM:SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled)
        $hasGitConfig = (Invoke-NativeCommand -ScriptBlock { git config --system -l } -IgnoreExitcode | Select-String 'core.longpaths=true') -as [bool]
		
		if ($hasGitConfig -and $hasRegKey) { return }
		if (-not $hasRegKey) { Write-PSFMessage -Level Warning -String 'Assert-WindowsLongPath.No.Registry' }
		if (-not $hasGitConfig) { Write-PSFMessage -Level Warning -String 'Assert-WindowsLongPath.No.GitCfg' }
		
		$exception = [System.InvalidOperationException]::new('Windows not sufficiently configured for long paths! Follow instructions for "Enabling long paths on Windows" on https://aka.ms/es/quickstart.')
		$errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, "ConfigurationError", 'InvalidOperation', $null)
		Write-PSFMessage -Level Warning -String 'Assert-WindowsLongPath.Failed' -Tag error
		$Cmdlet.ThrowTerminatingError($errorRecord)
    }
}