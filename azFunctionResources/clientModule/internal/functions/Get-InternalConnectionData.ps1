function Get-InternalConnectionData
{
<#
	.SYNOPSIS
		Creates parameter hashtables for Invoke-RestMethod calls.
	
	.DESCRIPTION
		Creates parameter hashtables for Invoke-RestMethod calls.
		This is the main abstraction layer for public functions.
	
	.PARAMETER Method
		The Rest Method to use when calling this function.
	
	.PARAMETER Parameters
		The PSBoundParameters object. Will be passed online using PowerShell Serialization.
	
	.PARAMETER FunctionName
		The name of the Azure Function to call.
		This should always be the condensed name of the function.
#>
	[CmdletBinding()]
	param (
		[string]
		$Method,
		
		$Parameters,
		
		[string]
		$FunctionName
	)
	
	process
	{
		try { $uri = '{0}{1}' -f (Get-PSFConfigValue -FullName 'AzOps.Client.Uri' -NotNull), $FunctionName }
		catch { $PSCmdlet.ThrowTerminatingError($_) }
		$header = @{ }
		
		#region Authentication
		$unprotectedToken = Get-PSFConfigValue -FullName 'AzOps.Client.UnprotectedToken'
		$protectedToken = Get-PSFConfigValue -FullName 'AzOps.Client.ProtectedToken'
		
		$authenticationDone = $false
		if ($protectedToken -and -not $authenticationDone)
		{
			$uri += '?code={0}' -f $protectedToken.GetNetworkCredential().Password
			$authenticationDone = $true
		}
		if ($unprotectedToken -and -not $authenticationDone)
		{
			$uri += '?code={0}' -f $unprotectedToken
			$authenticationDone = $true
		}
		if (-not $authenticationDone)
		{
			throw "No Authentication configured!"
		}
		#endregion Authentication
		
		
		@{
			Method  = $Method
			Uri	    = $uri
			Headers = $header
			Body    = (@{
				__SerializedParameters = ($Parameters | ConvertTo-PSFHashtable | ConvertTo-PSFClixml)
				__PSSerialize		   = $true
			} | ConvertTo-Json)
		}
	}
}