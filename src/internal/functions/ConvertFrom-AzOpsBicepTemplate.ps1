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
            Array of strings, already converted base template, if file is on list skip conversion.
        .PARAMETER ConvertedParameter
            Array of strings, already converted parameter, if file is on list skip conversion.
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
        [string[]]
        $ConvertedTemplate,
        [string[]]
        $ConvertedParameter,
        [switch]
        $CompareDeploymentToDeletion
    )

    begin {
        # Assert bicep binaries
        Assert-AzOpsBicepDependency -Cmdlet $PSCmdlet
        # Default transpiled values to false
        $transpiledTemplateNew = $false
        $transpiledParametersNew = $false
    }
    process {
        if ($CompareDeploymentToDeletion) {
            # Avoid adding files destined for deletion to a deployment list
            if ($BicepTemplatePath -in $deleteSet -or $BicepTemplatePath -in ($deleteSet | Resolve-Path).Path) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.DeployDeletionOverlap' -LogStringValues $BicepTemplatePath
                continue
            }
        }
        $transpiledTemplatePath = [IO.Path]::GetFullPath("$($BicepTemplatePath -replace '\.bicep', '.json')")
        if ($transpiledTemplatePath -notin $ConvertedTemplate) {
            # Convert bicep template
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate' -LogStringValues $BicepTemplatePath, $transpiledTemplatePath
            Invoke-AzOpsNativeCommand -ScriptBlock { bicep build $bicepTemplatePath --outfile $transpiledTemplatePath }
            $transpiledTemplateNew = $true
            # Check if bicep build created (ARM) template
            if (-not (Test-Path $transpiledTemplatePath)) {
                # If bicep build did not produce file exit with error
                Write-AzOpsMessage -LogLevel Error -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepTemplate.Error' -LogStringValues $BicepTemplatePath
                throw
            }
        }
        if (-not $SkipParam) {
            if (-not $BicepParamTemplatePath) {
                # Check if bicep template has associated bicepparam file
                $bicepParametersPath = $BicepTemplatePath -replace '\.bicep', '.bicepparam'
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam' -LogStringValues $BicepTemplatePath, $bicepParametersPath
            }
            elseif ($BicepParamTemplatePath) {
                # BicepParamTemplatePath path provided as input
                $bicepParametersPath = $BicepParamTemplatePath
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam' -LogStringValues $BicepTemplatePath, $bicepParametersPath
            }
            if ($CompareDeploymentToDeletion) {
                # Avoid adding files destined for deletion to a deployment list
                if ($bicepParametersPath -in $deleteSet -or $bicepParametersPath -in ($deleteSet | Resolve-Path).Path) {
                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.DeployDeletionOverlap' -LogStringValues $bicepParametersPath
                    $skipParameters = $true
                }
            }
            if (-not $skipParameters -and $bicepParametersPath -and (Test-Path $bicepParametersPath)) {
                $transpiledParametersPath = [IO.Path]::GetFullPath("$($bicepParametersPath -replace '\.bicepparam', '.parameters.json')")
                if ($transpiledParametersPath -notin $ConvertedParameter) {
                    # Convert bicepparam to ARM parameter file
                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam' -LogStringValues $bicepParametersPath, $transpiledParametersPath
                    Invoke-AzOpsNativeCommand -ScriptBlock { bicep build-params $bicepParametersPath --outfile $transpiledParametersPath }
                    $transpiledParametersNew = $true
                    # Check if bicep build-params created (ARM) parameters
                    if (-not (Test-Path $transpiledParametersPath)) {
                        # If bicep build-params did not produce file exit with error
                        Write-AzOpsMessage -LogLevel Error -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.ConvertBicepParam.Error' -LogStringValues $bicepParametersPath
                        throw
                    }
                }
            }
            else {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertFrom-AzOpsBicepTemplate.Resolve.BicepParam.NotFound' -LogStringValues $BicepTemplatePath
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