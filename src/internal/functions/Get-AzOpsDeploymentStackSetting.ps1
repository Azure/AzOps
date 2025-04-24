function Get-AzOpsDeploymentStackSetting {

    <#
        .SYNOPSIS
            Identifies and resolves the deployment stack configuration for a given template file, ensuring proper handling of excluded files and stack settings.
        .DESCRIPTION
            Processes a specified template file path to determine its associated deployment stack configuration.
            It checks for metadata, file variants, and exclusion patterns to identify whether the file is part of a deployment stack.
            If a deployment stack is found, it retrieves and returns the stack's settings and template file path.
            The function also handles exclusions defined in the stack configuration and logs relevant messages for debugging and tracing purposes.
        .PARAMETER TemplateFilePath
            The file path of the template to be processed. This should point to a JSON or Bicep file that may be part of a deployment stack.
        .EXAMPLE
            > $result = Get-AzOpsDeploymentStackSetting -TemplateFilePath "C:\Templates\example.bicep"
    #>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $TemplateFilePath
    )

    begin {
        $result = [PSCustomObject] @{
            DeploymentStackTemplateFilePath = $null
            DeploymentStackSettings         = $null
        }
    }

    process {

        $templateContent = Get-Content -Path $TemplateFilePath | ConvertFrom-Json -AsHashtable
        if ($templateContent.metadata._generator.name -eq "AzOps") {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStack.Metadata.AzOps' -LogStringValues $TemplateFilePath
            return
        }

        if ($TemplateFilePath.EndsWith('.json') -and -not $TemplateFilePath.EndsWith('parameters.json')) {
            # Generate a list of potential file names to check
            $fileName = Split-Path -Path $TemplateFilePath -Leaf
            $fileVariants = @($fileName)
            if ($fileName -like '*.json') {
                $fileVariants += $fileName -replace '\.json$', '.bicep'
            }
            elseif ($fileName -like '*.bicep') {
                $fileVariants += $fileName -replace '\.bicep$', '.json'
            }
            $stackTemplatePath = $TemplateFilePath -replace '\.json$', '.deploymentStacks.json'
            $parentStackPath = Join-Path -Path (Split-Path -Path $TemplateFilePath) -ChildPath ".deploymentStacks.json"
            if (Test-Path $stackTemplatePath) {
                $stackContent = Get-Content -Path $stackTemplatePath -Raw | ConvertFrom-Json -Depth 100
                if ($stackContent.excludedAzOpsFiles -and $stackContent.excludedAzOpsFiles.Count -gt 0) {
                    # Check if any of the file variants match the exclusion patterns
                    if ($fileVariants | Where-Object { $stackContent.excludedAzOpsFiles -match $_ }) {
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.ExcludedFromDeploymentStack' -LogStringValues $TemplateFilePath, $stackTemplatePath
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStackTemplateFilePath' -LogStringValues $stackTemplatePath, $TemplateFilePath
                        $result.DeploymentStackTemplateFilePath = $stackTemplatePath
                        $stackContent.PSObject.Properties.Remove('excludedAzOpsFiles')
                        $result.DeploymentStackSettings = $stackContent | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
                        return $result
                    }
                }
            }
            if (Test-Path $parentStackPath) {
                $fileName = Split-Path -Path $TemplateFilePath -Leaf
                $parentStackContent = Get-Content -Path $parentStackPath -Raw | ConvertFrom-Json -Depth 100
                if ($parentStackContent.excludedAzOpsFiles -and $parentStackContent.excludedAzOpsFiles.Count -gt 0) {
                    # Check if any of the file variants match the exclusion patterns
                    if ($fileVariants | Where-Object { $parentStackContent.excludedAzOpsFiles -match $_ }) {
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.ExcludedFromDeploymentStack' -LogStringValues $TemplateFilePath, $parentStackPath
                        return $result
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStackTemplateFilePath' -LogStringValues $parentStackPath, $TemplateFilePath
                        $result.DeploymentStackTemplateFilePath = $parentStackPath
                        $parentStackContent.PSObject.Properties.Remove('excludedAzOpsFiles')
                        $result.DeploymentStackSettings = $parentStackContent | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
                        return $result
                    }
                }
            }
            else {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.NoDeploymentStackFound' -LogStringValues $TemplateFilePath
                return $result
            }
        }

    }
}