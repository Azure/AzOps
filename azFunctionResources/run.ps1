param (
	$Request,
	
	$TriggerMetadata
)

$parameterObject = Convert-AzureFunctionParameter -Request $Request
$parameters = $parameterObject.Parameters
try { $data = %functionname% @parameters }
catch
{
	Write-AzureFunctionOutput -Value "Failed to execute: $_" -Status InternalServerError
	return
}

Write-AzureFunctionOutput -Value $data -Serialize:$parameterObject.Serialize