function Write-AzureFunctionOutput
{
<#
	.SYNOPSIS
		Write output equally well from Azure Functions or locally.
	
	.DESCRIPTION
		Write output equally well from Azure Functions or locally.
		When calling this command, call return straight after it.
		Use Write-AzureFunctionStatus first if an error should be returned, then specify an error text here.
	
	.PARAMETER Value
		The value data to return.
		Either an error message
	
	.PARAMETER Serialize
		Return the output object as compressed clixml string.
		You can use ConvertFrom-PSFClixml to restore the object on the recipient-side.
	
	.EXAMPLE
		PS C:\> Write-AzureFunctionOutput -Value $result
	
		Writes the content of $result as output.
	
	.EXAMPLE
		PS C:\> Write-AzureFunctionOutput -Value $result -Serialize
	
		Writes the content of $result as output.
		If called from Azure Functions, it will convert the output as compressed clixml string.
		
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		$Value,
		
		[switch]
		$Serialize,
		
		[System.Net.HttpStatusCode]
		$Status = [System.Net.HttpStatusCode]::OK
	)
	
	if ($Serialize)
	{
		$Value = $Value | ConvertTo-PSFClixml
	}
	
	Push-OutputBinding -Name Response -Value (
		[HttpResponseContext]@{
			StatusCode = $Status
			Body	   = $Value
		}
	)
}