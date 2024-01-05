function ConvertFrom-AzOpsBicepTemplate {
    <#
        .SYNOPSIS
            Transpiles bicep template and associated bicepparam to Azure Resource Manager (ARM) template.
            The json file will be created in the same folder as the bicep file.
        .PARAMETER BicepTemplatePath
            BicepTemplatePath.
        .PARAMETER BicepParamTemplatePath
            BicepParamTemplatePath, when provided function does not attempt default parameter file discovery.
        .PARAMETER SkipParam
            Switch when set will avoid parameter file discovery.
        .PARAMETER ConvertedTemplate
            Array of already converted base template, if file is on list skip conversion.
        .PARAMETER ConvertedParameter
            Array of already converted parameter, if file is on list skip conversion.
        .EXAMPLE
            ConvertFrom-AzOpsBicepTemplate -BicepTemplatePath "root/tenant root group (xxxx-xxxx-xxxx-xxxx-xxxx)/es (es)/subscription (xxxx-xxxx-xxxx-xxxx)/resource-rg/main.bicep"
            transpiledTemplatePath      : root/tenant root group (xxxx-xxxx-xxxx-xxxx-xxxx)/es (es)/subscription (xxxx-xxxx-xxxx-xxxx)/resource-rg/main.json
            transpiledTemplateNew       : True
            transpiledParametersPath    : root/tenant root group (xxxx-xxxx-xxxx-xxxx-xxxx)/es (es)/subscription (xxxx-xxxx-xxxx-xxxx)/resource-rg/main.parameters.json
            transpiledParametersNew     : True
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $BicepTemplatePath,
        [string]
        $BicepParamTemplatePath,
        [switch]
        $SkipParam,
        [array]
        $ConvertedTemplate,
        [array]
        $ConvertedParameter
    )

    begin {
        # Assert bicep binaries
        Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
        # Default transpiled values to false
        $transpiledTemplateNew = $false
        $transpiledParametersNew = $false
    }
    process {
        $transpiledTemplatePath = [IO.Path]::GetFullPath("$($BicepTemplatePath -replace '\.bicep', '.json')")
        if ($transpiledTemplatePath -notin $ConvertedTemplate) {
            # Convert bicep template
            Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate' -StringValues $BicepTemplatePath, $transpiledTemplatePath
            Invoke-AzOpsNativeCommand -ScriptBlock { bicep build $bicepTemplatePath --outfile $transpiledTemplatePath }
            $transpiledTemplateNew = $true
            # Check if bicep build created (ARM) template
            if (-not (Test-Path $transpiledTemplatePath)) {
                # If bicep build did not produce file exit with error
                Write-PSFMessage -Level Error -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate.Error' -StringValues $BicepTemplatePath
                throw
            }
        }
        if (-not $SkipParam) {
            if (-not $BicepParamTemplatePath) {
                # Check if bicep template has associated bicepparam file
                $bicepParametersPath = $BicepTemplatePath -replace '\.bicep', '.bicepparam'
                Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam' -StringValues $BicepTemplatePath, $bicepParametersPath
            }
            elseif ($BicepParamTemplatePath) {
                # BicepParamTemplatePath path provided as input
                $bicepParametersPath = $BicepParamTemplatePath
                Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam' -StringValues $BicepTemplatePath, $bicepParametersPath
            }
            if ($bicepParametersPath -and (Test-Path $bicepParametersPath)) {
                $transpiledParametersPath = [IO.Path]::GetFullPath("$($bicepParametersPath -replace '\.bicepparam', '.parameters.json')")
                if ($transpiledParametersPath -notin $ConvertedParameter) {
                    # Convert bicepparam to ARM parameter file
                    Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam' -StringValues $bicepParametersPath, $transpiledParametersPath
                    Invoke-AzOpsNativeCommand -ScriptBlock { bicep build-params $bicepParametersPath --outfile $transpiledParametersPath }
                    $transpiledParametersNew = $true
                    # Check if bicep build-params created (ARM) parameters
                    if (-not (Test-Path $transpiledParametersPath)) {
                        # If bicep build-params did not produce file exit with error
                        Write-PSFMessage -Level Error -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam.Error' -StringValues $bicepParametersPath
                        throw
                    }
                }
            }
            else {
                Write-PSFMessage -Level Verbose -String 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam.NotFound' -StringValues $BicepTemplatePath
            }
        }
        # Return transpiled (ARM) template paths
        $return = [PSCustomObject]@{
            transpiledTemplatePath   = $transpiledTemplatePath
            transpiledTemplateNew    = $transpiledTemplateNew
            transpiledParametersPath = $transpiledParametersPath
            transpiledParametersNew  = $transpiledParametersNew
        }
        return $return
    }
}