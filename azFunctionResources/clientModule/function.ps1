function %functionname%
{
	%parameter%
	
	process
	{
		$invokeParameters = Get-InternalConnectionData -Method '%method%' -Parameter $PSBoundParameters -FunctionName '%condensedname%'
		Invoke-RestMethod @invokeParameters | ConvertFrom-PSFClixml
	}
}