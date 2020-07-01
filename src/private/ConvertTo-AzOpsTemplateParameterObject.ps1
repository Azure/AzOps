function ConvertTo-AzOpsTemplateParameterObject {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        $FilePath
    )

    begin {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        $parameters = Get-Content -Path $filepath | ConvertFrom-Json
    }
    process {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        $parametersObj = @'
        {
            "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json",
            "contentVersion": "1.0.0.0",
            "parameters": {
                "input": {
                    "value": "null"
                }
            }
        }
'@ | Convertfrom-Json

        $parametersObj.parameters.input.value = $parameters
        return $parametersObj
    }
    end {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}