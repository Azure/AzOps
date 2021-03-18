function ConvertTo-AzOpsState {

    <#
        .SYNOPSIS
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
        .DESCRIPTION
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
            It is normally executed and orchestrated through the Initialize-AzOpsRepository cmdlet. As most of the AzOps-cmdlets, it is dependant on the AzOpsAzManagementGroup and AzOpsSubscriptions variables.
            Commandlet will look into jq filter is template directory for the specific one before using the generic one at the root of the module
        .PARAMETER Resource
            Object with resource as input
        .PARAMETER ExportPath
            ExportPath is used if resource needs to be exported to other path than the AzOpsScope path
        .PARAMETER ReturnObject
            Used if to return object in pipeline instead of exporting file
        .PARAMETER ExportRawTemplate
            Used in cases you want to return the template without the custom parameters json schema
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .EXAMPLE
            Initialize-AzOpsEnvironment
            $policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
            ConvertTo-AzOpsState -Resource $policy
            Export custom policy definition to the AzOps StatePath
        .EXAMPLE
            Initialize-AzOpsEnvironment
            $policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
            ConvertTo-AzOpsState -Resource $policy -ReturnObject
            Name                           Value
            ----                           -----
            $schema                        http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#
            contentVersion                 1.0.0.0
            parameters                     {input}
            Serialize custom policy definition to the AzOps format, return object instead of export file
        .INPUTS
            Resource
        .OUTPUTS
            Resource in AzOpsState json format or object returned as [PSCustomObject] depending on parameters used
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('MG', 'Role', 'Assignment', 'CustomObject', 'ResourceGroup')]
        $Resource,

        [string]
        $ExportPath,

        [switch]
        $ReturnObject,

        [switch]
        $ExportRawTemplate,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $StatePath,

        [string]
        $JqTemplatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.JqTemplatePath')
    )

    begin {
        Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Starting'
    }

    process {
        Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Processing' -StringValues $Resource

        if (-not $ExportPath) {
            if ($Resource.Id) {
                $objectFilePath = (New-AzOpsScope -scope $Resource.id -StatePath $StatePath).statepath
            }
            elseif ($Resource.ResourceId) {
                $objectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
            }
            else {
                Write-PSFMessage -Level Error -String "ConvertTo-AzOpsState.NoExportPath" -StringValues $Resource.GetType()
            }
        }
        else {
            $objectFilePath = $ExportPath
        }
        # Create folder structure if it doesn't exist
        if (-not (Test-Path -Path $objectFilePath)) {
            Write-PSFMessage -String 'ConvertTo-AzOpsState.File.Create' -StringValues $objectFilePath
            $null = New-Item -Path $objectFilePath -ItemType "file" -Force
        }
        else {
            Write-PSFMessage -String 'ConvertTo-AzOpsState.File.UseExisting' -StringValues $objectFilePath
        }

        # if the export file path ends with parameter
        $generateTemplateParameter = $objectFilePath.EndsWith('.parameters.json') ? $true : $false
        Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplateParameter' -StringValues "$generateTemplateParameter" -FunctionName 'ConvertTo-AzOpsState'

        $resourceType = $null
        switch ($Resource) {
            { $_.ResourceType } {
                Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved.ResourceType' -StringValues "$($Resource.ResourceType)" -FunctionName 'ConvertTo-AzOpsState'
                $resourceType = $_.ResourceType
                break
            }
            { $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] -or
                $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupChildInfo] } {
                # determine based on PowerShell Class
                # To do change the serialization of subscription child object
                Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -StringValues "$($_.GetType())" -FunctionName 'ConvertTo-AzOpsState'
                $resourceType = 'Microsoft.Management/managementGroups'
                break
            }
            #Controlled group for raw  objects
            { $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant] -or
                $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] -or
                $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] } {
                Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -StringValues  "$($_.GetType())" -FunctionName 'ConvertTo-AzOpsState'
                break
            }
            Default {
                Write-PSFMessage -Level Warning -String 'ConvertTo-AzOpsState.ObjectType.Resolved.Generic'  -StringValues "$($_.GetType())" -FunctionName 'ConvertTo-AzOpsState'
                break
            }
        }
        if ($resourceType) {
            $providerNamespace = ($resourceType -split '/' | Select-Object -First 1)
            Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplate.ProviderNamespace' -StringValues $providerNamespace -FunctionName 'ConvertTo-AzOpsState'

            $resourceTypeName = (($resourceType -split '/', 2) | Select-Object -Last 1)
            Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplate.ResourceTypeName' -StringValues $resourceTypeName -FunctionName 'ConvertTo-AzOpsState'


            $jqRemoveTemplate = (
                (Test-Path (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.jq"))) ?
                (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.jq")):
                (Join-Path $JqTemplatePath -ChildPath "generic.jq")
            )
            Write-PSFMessage -String 'ConvertTo-AzOpsState.Jq.Remove' -StringValues $jqRemoveTemplate -FunctionName 'ConvertTo-AzOpsState'
            #If we were able to determine resourceType, apply filter and write template or template parameter files based on output filename.
            $object = $Resource | ConvertTo-Json -Depth 100 | jq -r -f $jqRemoveTemplate | ConvertFrom-Json

            if ($ReturnObject) {
                return $object
            }
            else {
                if ($generateTemplateParameter) {
                    #Generating Template Parameter
                    Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplateParameter' -FunctionName 'ConvertTo-AzOpsState'
                    $jqJsonTemplate = (Test-Path (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.parameters.jq"))) ?
                    (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.parameters.jq")):
                    (Join-Path $JqTemplatePath -ChildPath "template.parameters.jq")

                    Write-PSFMessage -String 'ConvertTo-AzOpsState.Jq.Template' -StringValues $jqJsonTemplate -FunctionName 'ConvertTo-AzOpsState'
                    $object = ($object | ConvertTo-Json -Depth 100 | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
                }
                else {
                    #Generating Template
                    Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplate' -StringValues "$true"  -FunctionName 'ConvertTo-AzOpsState'
                    $jqJsonTemplate = (Test-Path (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.template.jq"))) ?
                    (Join-Path $JqTemplatePath -ChildPath (Join-Path $providerNamespace -ChildPath "$resourceTypeName.template.jq")):
                    (Join-Path $JqTemplatePath -ChildPath "template.jq")

                    Write-PSFMessage -String 'ConvertTo-AzOpsState.Jq.Template' -StringValues $jqJsonTemplate -FunctionName 'ConvertTo-AzOpsState'
                    $object = ($object | ConvertTo-Json -Depth 100 | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
                    #determine resource api version to replace it in type
                    if (
                        ($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }) -and
                        (($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }).ResourceTypes | Where-Object { $_.ResourceTypeName -eq $resourceTypeName })
                    ) {
                        $apiVersions = (($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }).ResourceTypes | Where-Object { $_.ResourceTypeName -eq $resourceTypeName }).ApiVersions[0]
                        Write-PSFMessage -String 'ConvertTo-AzOpsState.GenerateTemplate.ApiVersion' -StringValues $resourceType, $apiVersions -FunctionName 'ConvertTo-AzOpsState'

                        $object.resources[0].apiVersion = $apiVersions
                        $object.resources[0].type = $resourceType
                    }
                    else {
                        Write-PSFMessage -Level Warning -String 'ConvertTo-AzOpsState.GenerateTemplate.NoApiVersion' -StringValues $resourceType -FunctionName 'ConvertTo-AzOpsState'
                    }

                    Write-PSFMessage -String 'ConvertTo-AzOpsState.Exporting' -StringValues $objectFilePath -FunctionName 'ConvertTo-AzOpsState'
                    ConvertTo-Json -InputObject $object -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force
                }
            }
        }
        else {
            Write-PSFMessage -String 'ConvertTo-AzOpsState.Exporting.Default' -StringValues $objectFilePath -FunctionName 'ConvertTo-AzOpsState'
            if ($ReturnObject) { return $Resource }
            else {
                ConvertTo-Json -InputObject $Resource -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force
            }
        }
    }
}