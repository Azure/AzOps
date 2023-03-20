function Get-AzOpsTemplateFile {

    <#
        .SYNOPSIS
            Takes file name input and returns first match, looks at Core.SkipCustomJqTemplate, Core.CustomJqTemplatePath followed by Core.JqTemplatePath.
        .DESCRIPTION
            Takes file name input and returns first match, looks at Core.SkipCustomJqTemplate, Core.CustomJqTemplatePath followed by Core.JqTemplatePath.
        .PARAMETER File
            Filename of template file to look for.
        .PARAMETER Fallback
            Fallback filename to look for if parameter:file is not found.
        .EXAMPLE
            > Get-AzOpsTemplateFile -File "templateChildResource.jq"
            Returns the following:
            /workspaces/AzOps/src/data/template/templateChildResource.jq
    #>

    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $File,

        [string]
        $Fallback,

        [string]
        $JqTemplatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.JqTemplatePath'),

        [string]
        $CustomJqTemplatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.CustomJqTemplatePath'),

        [bool]
        $SkipCustomJqTemplate = (Get-PSFConfigValue -FullName 'AzOps.Core.SkipCustomJqTemplate')
    )

    process {
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing' -StringValues $File
        # Evaluate JqTemplate Conditions
        if ($SkipCustomJqTemplate) {
            # Use default module templates only
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Path' -StringValues $File, $JqTemplatePath
            if ($Fallback) {
                # Process with Fallback
                Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Fallback' -StringValues $File, $Fallback
                $return = (Test-Path (Join-Path $JqTemplatePath -ChildPath $File)) ?
                (Get-Item (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                (Get-Item (Join-Path $JqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
            }
            else {
                # Process without Fallback
                if (Test-Path (Join-Path $JqTemplatePath -ChildPath $File)) {
                    $return = (Get-Item (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                }
            }
        }
        else {
            # Use custom templates
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Path' -StringValues $File, $CustomJqTemplatePath
            if ($Fallback) {
                # Process with Fallback
                Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Fallback' -StringValues $File, $Fallback
                $return = (Test-Path (Join-Path $CustomJqTemplatePath -ChildPath $File)) ?
                (Get-Item (Join-Path $CustomJqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                (Get-Item (Join-Path $CustomJqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
                if (-not $return) {
                    # Use default templates since no custom templates was found
                    Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Path' -StringValues $File, $JqTemplatePath
                    $return = (Test-Path (Join-Path $JqTemplatePath -ChildPath $File)) ?
                    (Get-Item (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                    (Get-Item (Join-Path $JqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
                }
            }
            else {
                # Process without Fallback
                if (Test-Path (Join-Path $CustomJqTemplatePath -ChildPath $File)) {
                    $return = (Get-Item (Join-Path $CustomJqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                }
                if (-not $return) {
                    # Use default templates since no custom templates was found
                    Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Path' -StringValues $File, $JqTemplatePath
                    if (Test-Path (Join-Path $JqTemplatePath -ChildPath $File)) {
                        $return = (Get-Item (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                    }
                }
            }
        }
        if ($return) {
            # Template file found
            Write-PSFMessage -Level Verbose -String 'Get-AzOpsTemplateFile.Processing.Found' -StringValues $return
            return ($return | Select-Object -First 1).VersionInfo.FileName
        }
        else {
            # No template file found, throw
            Write-PSFMessage -Level Error -String 'Get-AzOpsTemplateFile.Processing.NotFound' -StringValues $File
            throw
        }
    }
}