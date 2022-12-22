function ConvertFrom-AzOpsBicepTemplate {
    <#
        .SYNOPSIS
            Transpiles bicep template to Azure Resource Manager (ARM) template.
            The json file will be created in the same folder as the bicep file.
        .PARAMETER BicepTemplatePath
            BicepTemplatePath
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $BicepTemplatePath
    )

    begin {
        # Assert bicep binaries
        Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
    }
    process {
        # Convert bicep template
        $transpiledTemplatePath = $BicepTemplatePath -replace '\.bicep', '.json'
        Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate' -StringValues $BicepTemplatePath, $transpiledTemplatePath
        Invoke-AzOpsNativeCommand -ScriptBlock { bicep build $bicepTemplatePath --outfile $transpiledTemplatePath }
        # Return transpiled ARM json path
        return $transpiledTemplatePath
    }
}