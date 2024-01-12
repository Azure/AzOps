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
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing' -LogStringValues $File
        # Evaluate JqTemplate Conditions
        if ($SkipCustomJqTemplate) {
            # Use default module templates only
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Path' -LogStringValues $File, $JqTemplatePath
            if ($Fallback) {
                # Process with Fallback
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Fallback' -LogStringValues $File, $Fallback
                $return = (Test-Path -Path (Join-Path $JqTemplatePath -ChildPath $File) -PathType Leaf) ?
                (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
            }
            else {
                # Process without Fallback
                if (Test-Path -Path (Join-Path $JqTemplatePath -ChildPath $File) -PathType Leaf) {
                    $return = (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                }
            }
        }
        else {
            # Use custom templates
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Path' -LogStringValues $File, $CustomJqTemplatePath
            if ($Fallback) {
                # Process with Fallback
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Fallback' -LogStringValues $File, $Fallback
                $return = (Test-Path -Path (Join-Path $CustomJqTemplatePath -ChildPath $File) -PathType Leaf) ?
                (Get-Item -Path (Join-Path $CustomJqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                (Get-Item -Path (Join-Path $CustomJqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
                if (-not $return) {
                    # Use default templates since no custom templates was found
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Path' -LogStringValues $File, $JqTemplatePath
                    $return = (Test-Path -Path (Join-Path $JqTemplatePath -ChildPath $File) -PathType Leaf) ?
                    (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue):
                    (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $Fallback) -ErrorAction SilentlyContinue)
                }
            }
            else {
                # Process without Fallback
                if (Test-Path -Path (Join-Path $CustomJqTemplatePath -ChildPath $File) -PathType Leaf) {
                    $return = (Get-Item -Path (Join-Path $CustomJqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                }
                if (-not $return) {
                    # Use default templates since no custom templates was found
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsTemplateFile.Processing.Path' -LogStringValues $File, $JqTemplatePath
                    if (Test-Path -Path (Join-Path $JqTemplatePath -ChildPath $File) -PathType Leaf) {
                        $return = (Get-Item -Path (Join-Path $JqTemplatePath -ChildPath $File) -ErrorAction SilentlyContinue)
                    }
                }
            }
        }
        if ($return) {
            # Template file found
            $return = ($return | Select-Object -First 1).VersionInfo.FileName
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsTemplateFile.Processing.Found' -LogStringValues $return
            return $return
        }
        else {
            # No template file found, throw
            Write-AzOpsMessage -LogLevel Error -LogString 'Get-AzOpsTemplateFile.Processing.NotFound' -LogStringValues $File
            throw
        }
    }
}