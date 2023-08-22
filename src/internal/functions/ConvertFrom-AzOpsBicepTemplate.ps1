function ConvertFrom-AzOpsBicepTemplate {
    <#
        .SYNOPSIS
            Transpiles bicep template and associated bicepparam to Azure Resource Manager (ARM) template.
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
        # Check if bicep build created (ARM) template
        if (-not (Test-Path $transpiledTemplatePath)) {
            # If bicep build did not produce file exit with error
            Write-PSFMessage -Level Error -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate.Error' -StringValues $BicepTemplatePath
            throw
        }
        # Check if bicep template has associated bicepparam file
        $bicepParametersPath = $BicepTemplatePath -replace '\.bicep', '.bicepparam'
        Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam' -StringValues $BicepTemplatePath, $bicepParametersPath
        if (Test-Path $bicepParametersPath) {
            # Convert bicepparam to ARM parameter file
            $transpiledParametersPath = $bicepParametersPath -replace '\.bicepparam', ('.parameters' + (Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix'))
            Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam' -StringValues $bicepParametersPath, $transpiledParametersPath
            Invoke-AzOpsNativeCommand -ScriptBlock { bicep build-params $bicepParametersPath --outfile $transpiledParametersPath }
            # Check if bicep build-params created (ARM) parameters
            if (-not (Test-Path $transpiledParametersPath)) {
                # If bicep build-params did not produce file exit with error
                Write-PSFMessage -Level Error -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam.Error' -StringValues $bicepParametersPath
                throw
        }
        }
        else {
            Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam.NotFound' -StringValues $BicepTemplatePath
        }
        # Return transpiled (ARM) template path
        return $transpiledTemplatePath
    }
}