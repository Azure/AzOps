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
        .PARAMETER ParameterTemplateFilePath
            the file path of an optional parameter template file associated with the TemplateFilePath.
        .PARAMETER ScopeObject
            An optional object that specifies the deployment scope, such as ResourceGroup, Subscription, or ManagementGroup.
        .PARAMETER ReverseLookup
            Indicates whether the function should perform a reverse lookup to identify the associated template file(s) for a given deployment stack file.
            When specified, the function attempts to resolve and return the template file paths that are part of the deployment stack configuration.
        .EXAMPLE
            > $result = Get-AzOpsDeploymentStackSetting -TemplateFilePath "C:\Templates\example.bicep" -ScopeObject (New-AzOpsScope -Path C:\Templates\example.bicep)
            > $result

            DeploymentStackTemplateFilePath : C:\Templates\example.deploymentStacks.json
            DeploymentStackSettings         : @{property1=value1; property2=value2}
            ReverseLookupTemplateFilePath   :

        .EXAMPLE
            > $result = Get-AzOpsDeploymentStackSetting -TemplateFilePath "C:\Templates\.deploymentStacks.json" -ReverseLookup
            > $result

            DeploymentStackTemplateFilePath :
            DeploymentStackSettings         :
            ReverseLookupTemplateFilePath   : {C:\Templates\example1.bicep, C:\Templates\example2.json}
    #>

    #region Parameters
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string]
        $TemplateFilePath,
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $ParameterTemplateFilePath,
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $ScopeObject,
        [Parameter(ValueFromPipeline = $true)]
        [switch]
        $ReverseLookup
    )
    #endregion

    begin {
        #region Helper Functions
        function Get-AzOpsDeploymentStackSettingReverseLookup {

            <#
                .SYNOPSIS
                    Performs a reverse lookup to identify associated template files for a deployment stack.
                .DESCRIPTION
                    This function checks if the provided template file is a root stack file and retrieves all associated
                    Bicep and JSON files in the same folder, excluding `.deploymentStacks.json` files.
                .PARAMETER TemplateFilePath
                    The path to the template file being processed.
                .PARAMETER result
                    A PSCustomObject to store the resolved file paths.
                .OUTPUTS
                    Updates the result object with the resolved file paths.
            #>

            param (
                [string]
                $TemplateFilePath,
                [PSCustomObject]
                $result
            )

            # Check if the file is a root stack file by matching its name
            if ((Split-Path -Path $TemplateFilePath -Leaf) -eq '.deploymentStacks.json') {
                # This is a root stack file
                $folderPath = Split-Path -Path $TemplateFilePath -Parent
                $folderPathLookup = Join-Path -Path $folderPath -ChildPath '*'

                # Retrieve all Bicep and JSON files in the folder
                $allTemplateFiles = Get-ChildItem -Path $folderPathLookup -File -Include *.bicep, *.json -Exclude *.deploymentStacks.json | Select-Object -ExpandProperty FullName
                $nonAzOpsFiles = @()

                foreach ($file in $allTemplateFiles) {
                    if ($file.EndsWith('.json')) {
                        # Check if the JSON file has AzOps metadata
                        $fileContent = Get-Content -Path $file | ConvertFrom-Json -AsHashtable
                        if ($fileContent.metadata._generator.name -eq "AzOps") {
                            Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStack.Metadata.AzOps' -LogStringValues $file
                        }
                        else {
                            $nonAzOpsFiles += $file
                        }
                    }
                    else {
                        $nonAzOpsFiles += $file
                    }
                }

                # Update the result object with the resolved file paths
                $result.ReverseLookupTemplateFilePath = $nonAzOpsFiles
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.ReverseLookup.TemplateFilePath' -LogStringValues $TemplateFilePath, $result.ReverseLookupTemplateFilePath
                return $result
            }
            elseif ($TemplateFilePath.EndsWith('.deploymentStacks.json') -and (Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $TemplateFilePath.Split('.')[-3] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','')) {
                # Handle parameter template stack files if AllowMultipleTemplateParameterFiles is true
                if (Test-Path -Path ($TemplateFilePath -replace '\.deploymentStacks.json$', '.bicepparam')) {
                    $result.ReverseLookupTemplateFilePath = $TemplateFilePath -replace '\.deploymentStacks.json$', '.bicepparam'
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.ReverseLookup.TemplateFilePath' -LogStringValues $TemplateFilePath, $result.ReverseLookupTemplateFilePath
                    return $result
                }
                elseif (Test-Path -Path ($TemplateFilePath -replace '\.deploymentStacks.json$', '.parameters.json')) {
                    $result.ReverseLookupTemplateFilePath = $TemplateFilePath -replace '\.deploymentStacks.json$', '.parameters.json'
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.ReverseLookup.TemplateFilePath' -LogStringValues $TemplateFilePath, $result.ReverseLookupTemplateFilePath
                    return $result
                }
            }
            else {
                # Handle dedicated template stack files
                if (Test-Path ($TemplateFilePath -replace '\.deploymentStacks.json$', '.bicep')) {
                    $result.ReverseLookupTemplateFilePath = $TemplateFilePath -replace '\.deploymentStacks.json$', '.bicep'
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.ReverseLookup.TemplateFilePath' -LogStringValues $TemplateFilePath, $result.ReverseLookupTemplateFilePath
                    return $result
                }
                if (Test-Path ($TemplateFilePath -replace '\.json$', '.json')) {
                    $result.ReverseLookupTemplateFilePath = $TemplateFilePath -replace '\.json$', '.json'
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.ReverseLookup.TemplateFilePath' -LogStringValues $TemplateFilePath, $result.ReverseLookupTemplateFilePath
                    return $result
                }
            }
        }
        function Get-AzOpsDeploymentStackFile {

            <#
                .SYNOPSIS
                    Resolves the deployment stack configuration for a given template file by identifying and processing the associated stack file.
                .DESCRIPTION
                    The `Get-AzOpsDeploymentStackFile` function evaluates a specified template file and its associated stack file to determine the deployment stack configuration.
                    It checks for the existence of the stack file, parses its content, and filters valid parameters based on the deployment scope.
                    The function also handles exclusions defined in the stack file, ensuring that excluded files are not processed as part of the deployment stack.
                    If the stack file is found and valid, the function returns the stack's settings and template file path.
                .PARAMETER StackPath
                    The file path of the deployment stack file to be evaluated. This file typically contains configuration settings for the deployment stack.
                .PARAMETER TemplateFilePath
                    The file path of the template file being processed. This should point to a JSON or Bicep file that may be part of a deployment stack.
                .PARAMETER ParameterTemplateFilePath
                    The file path of an optional parameter template file associated with the TemplateFilePath. This is used when multiple template parameter files are allowed.
                .PARAMETER FileVariants
                    A switch parameter indicating whether to check for file variants (e.g., `.bicep` and `.json` versions of the template file) when evaluating exclusions.
                .PARAMETER result
                    A PSCustomObject used to store the resolved deployment stack settings and template file path. This object is updated and returned by the function.
                .PARAMETER ScopeObject
                    An object specifying the deployment scope, such as ResourceGroup, Subscription, or ManagementGroup. This determines the type of deployment stack command to use.
                .OUTPUTS
                    PSCustomObject
                        Returns a custom object containing the following properties:
                        - DeploymentStackTemplateFilePath: The file path of the resolved deployment stack file.
                        - DeploymentStackSettings: A hashtable of filtered parameters from the stack file.
                        - ReverseLookupTemplateFilePath: Null (not used in this function).
            #>

            param (
                [string]
                $StackPath,
                [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
                [string]
                $TemplateFilePath,
                [string]
                $ParameterTemplateFilePath,
                [switch]
                $FileVariants,
                [PSCustomObject]
                $result,
                [object]
                $ScopeObject
            )
            if ($StackPath) {
                # Check if the stack file exists
                if (Test-Path $StackPath) {
                    try {
                        # Read and parse the JSON content from the stack file
                        $stackContent = Get-Content -Path $StackPath -Raw | ConvertFrom-Json -AsHashtable
                    }
                    catch {
                        # Handle errors during JSON conversion or other operations
                        Write-AzOpsMessage -LogLevel Error -LogString 'Get-AzOpsDeploymentStackSetting.Setting.Error' -LogStringValues $StackPath, $TemplateFilePath
                        $result.DeploymentStackTemplateFilePath = $StackPath
                        $result.DeploymentStackSettings = $null
                        return $result
                    }
                    if ($ScopeObject.ResourceGroup -and $ScopeObject.ResourceGroup -ne "") {
                        $command = "New-AzResourceGroupDeploymentStack"
                    }
                    elseif ($ScopeObject.Subscription -and $ScopeObject.Subscription -ne "") {
                        $command = "New-AzSubscriptionDeploymentStack"
                    }
                    elseif ($ScopeObject.ManagementGroup -and $ScopeObject.ManagementGroup -ne "") {
                        $command = "New-AzManagementGroupDeploymentStack"
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Error -LogString 'Get-AzOpsDeploymentStackSetting.Scope.Error' -LogStringValues $StackPath, $TemplateFilePath
                        return $result
                    }
                    $allowedSettings = @(
                        "ActionOnUnmanage",
                        "DenySettingsMode",
                        "DenySettingsExcludedPrincipal",
                        "DenySettingsExcludedAction",
                        "DenySettingsApplyToChildScopes",
                        "BypassStackOutOfSyncError"
                    )
                    # Get the valid parameters for the command
                    $validParameters = (Get-Command $command).Parameters.Keys | Where-Object { $_ -in $allowedSettings }

                    # Initialize an empty hashtable to store the filtered parameters
                    $finalParameters = @{}

                    # Iterate over the keys in the stack content
                    foreach ($key in $stackContent.Keys) {
                        # Check if the key is a valid parameter
                        if ($validParameters -contains $key) {
                            # Add the key-value pair to the prepared parameters
                            $finalParameters[$key] = $stackContent[$key]
                        }
                    }
                    # Handle excluded files
                    if ($stackContent.excludedAzOpsFiles -and ($stackContent.excludedAzOpsFiles).Count -gt 0 -and $FileVariants) {
                        # Generate a list of potential file names to check
                        $fileName = Split-Path -Path $TemplateFilePath -Leaf
                        $checkFileVariants = @($fileName)
                        if ($fileName -like '*.json') {
                            $checkFileVariants += $fileName -replace '\.json$', '.bicep'
                        }
                        elseif ($fileName -like '*.bicep') {
                            $checkFileVariants += $fileName -replace '\.bicep$', '.json'
                        }
                        # Check if the parameter template file ends with 'parameters.json', if multiple template parameter files are allowed, and the file name matches the configured suffix.
                        if ($ParameterTemplateFilePath.EndsWith('parameters.json') -and (Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $ParameterTemplateFilePath.Split('.')[-3] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','') ) {
                            # Extract the parameter file name and add it to the list of file variants
                            $parameterFileName = Split-Path -Path $ParameterTemplateFilePath -Leaf
                            $checkFileVariants += $parameterFileName
                            $checkFileVariants += $parameterFileName -replace '\.parameters.json$', '.bicepparam'
                        }
                        $matchedFile = $checkFileVariants | Where-Object { $stackContent.excludedAzOpsFiles -eq $_ }
                        if ($matchedFile) {
                            # Log the exclusion
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.ExcludedFromDeploymentStack' -LogStringValues $TemplateFilePath, $StackPath, $matchedFile
                        }
                        else {
                            # Update the result object if the file is not excluded
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStackTemplateFilePath' -LogStringValues $StackPath, $TemplateFilePath
                            $result.DeploymentStackTemplateFilePath = $StackPath
                            $result.DeploymentStackSettings = $finalParameters
                        }
                    }
                    else {
                        # Update the result object if there are no excluded files
                        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStackTemplateFilePath' -LogStringValues $StackPath, $TemplateFilePath
                        $result.DeploymentStackTemplateFilePath = $StackPath
                        $result.DeploymentStackSettings = $finalParameters
                    }
                    return $result
                }
                else {
                    # Log if the stack file does not exist
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.NoDeploymentStackFound' -LogStringValues $StackPath
                    return $result
                }
            }
            else {
                if ($ParameterTemplateFilePath.EndsWith('parameters.json') -and (Get-PSFConfigValue -FullName 'AzOps.Core.AllowMultipleTemplateParameterFiles') -eq $true -and $ParameterTemplateFilePath.Split('.')[-3] -match $(Get-PSFConfigValue -FullName 'AzOps.Core.MultipleTemplateParameterFileSuffix').Replace('.','') -and (Test-Path -Path ($ParameterTemplateFilePath -replace '\.parameters.json$', '.deploymentStacks.json'))) {
                    $stackParameterTemplatePath = $ParameterTemplateFilePath -replace '\.parameters.json$', '.deploymentStacks.json'
                    $evaluateStackTemplatePath = Get-AzOpsDeploymentStackFile -StackPath $stackParameterTemplatePath -TemplateFilePath $TemplateFilePath -ParameterTemplateFilePath $ParameterTemplateFilePath -result $result -ScopeObject $ScopeObject
                    if ($evaluateStackTemplatePath.DeploymentStackTemplateFilePath) {
                        $result = $evaluateStackTemplatePath
                        return $result
                    }
                }
                else {
                    $stackTemplatePath = ($TemplateFilePath -replace '\.json$', '.deploymentStacks.json')
                    $evaluateStackTemplatePath = Get-AzOpsDeploymentStackFile -StackPath $stackTemplatePath -TemplateFilePath $TemplateFilePath -ParameterTemplateFilePath $ParameterTemplateFilePath -FileVariants -result $result -ScopeObject $ScopeObject
                    if ($evaluateStackTemplatePath.DeploymentStackTemplateFilePath) {
                        $result = $evaluateStackTemplatePath
                        return $result
                    }
                    else {
                        $parentStackPath = Join-Path -Path (Split-Path -Path $TemplateFilePath) -ChildPath ".deploymentStacks.json"
                        $evaluateParentStackPath = Get-AzOpsDeploymentStackFile -StackPath $parentStackPath -TemplateFilePath $TemplateFilePath -ParameterTemplateFilePath $ParameterTemplateFilePath -FileVariants -result $result -ScopeObject $ScopeObject
                        if ($evaluateParentStackPath.DeploymentStackTemplateFilePath) {
                            $result = $evaluateParentStackPath
                            return $result
                        }
                        else {
                            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.NoDeploymentStackFound' -LogStringValues $TemplateFilePath
                            return $result
                        }
                    }
                }
            }
        }
        #endregion
        # Initialize the result object with default null values
        $result = [PSCustomObject] @{
            DeploymentStackTemplateFilePath = $null
            DeploymentStackSettings         = $null
            ReverseLookupTemplateFilePath   = $null
        }
    }

    process {
        # Handle ReverseLookup Mode
        if ($ReverseLookup) {
            $validatedResult = Get-AzOpsDeploymentStackSettingReverseLookup -TemplateFilePath $TemplateFilePath -result $result
            if ($validatedResult) {
                $result = $validatedResult
                return $result
            }
        }
        # Process the template file to determine its deployment stack configuration
        $templateContent = Get-Content -Path $TemplateFilePath -Raw | ConvertFrom-Json -AsHashtable
        if ($templateContent.metadata._generator.name -eq "AzOps") {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.DeploymentStack.Metadata.AzOps' -LogStringValues $TemplateFilePath
            return
        }
        # Process the call
        $evaluateStackTemplatePath = Get-AzOpsDeploymentStackFile -TemplateFilePath $TemplateFilePath -ParameterTemplateFilePath $ParameterTemplateFilePath -result $result -ScopeObject $ScopeObject
        if ($evaluateStackTemplatePath.DeploymentStackTemplateFilePath) {
            $result = $evaluateStackTemplatePath
            return $result
        }
        else {
            Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsDeploymentStackSetting.Resolve.NoDeploymentStackFound' -LogStringValues $TemplateFilePath
            return $result
        }
    }
}