function ConvertTo-AzOpsState {

    <#
        .SYNOPSIS
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
        .DESCRIPTION
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
            It is normally executed and orchestrated through the Invoke-AzOpsPull cmdlet. As most of the AzOps-cmdlets, it is dependant on the AzOpsAzManagementGroup and AzOpsSubscriptions variables.
            Cmdlet will look into jq filter is template directory for the specific one before using the generic one at the root of the module
        .PARAMETER Resource
            Object with resource as input
        .PARAMETER ExportPath
            ExportPath is used if resource needs to be exported to other path than the AzOpsScope path
        .PARAMETER ReturnObject
            Used if to return object in pipeline instead of exporting file
        .PARAMETER ChildResource
            The ChildResource contains details of the child resource
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .EXAMPLE
            $policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
            ConvertTo-AzOpsState -Resource $policy
            Export custom policy definition to the AzOps StatePath
        .EXAMPLE
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
        $Resource,

        [string]
        $ExportPath,

        [switch]
        $ReturnObject,

        [hashtable]
        $ChildResource,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $StatePath,

        [string]
        $JqTemplatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.JqTemplatePath')
    )

    begin {
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'ConvertTo-AzOpsState.Starting'
    }

    process {
        if ($ChildResource) {
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Processing' -LogStringValues $ChildResource.resourceName

            $objectFilePath = (New-AzOpsScope -scope $ChildResource.parentResourceId -ChildResource $ChildResource -StatePath $Statepath).statepath

            $jqJsonTemplate = Get-AzOpsTemplateFile -File "templateChildResource.jq"

            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Subscription.ChildResource.Jq.Template' -LogStringValues $jqJsonTemplate
            $object = ($Resource | ConvertTo-Json -Depth 100 -EnumsAsStrings | jq -r '--sort-keys' | jq -r -f $jqJsonTemplate | ConvertFrom-Json)

            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Subscription.ChildResource.Exporting' -LogStringValues $objectFilePath
            ConvertTo-Json -InputObject $object -Depth 100 -EnumsAsStrings | Set-Content -Path $objectFilePath -Encoding UTF8 -Force
            return
        }
        else {
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Processing' -LogStringValues $Resource.id
        }

        if (-not $ExportPath) {
            if ($Resource.Id) {
                # Handle subscription-only scenarios without managementGroup access
                if ($Resource -is [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription]) {
                    $objectFilePath = (New-AzOpsScope -scope "/subscriptions/$($Resource.id)" -StatePath $StatePath).statepath
                }
                else {
                    $objectFilePath = (New-AzOpsScope -scope $Resource.id -StatePath $StatePath).statepath
                }
            }
            elseif ($Resource.ResourceId) {
                $objectFilePath = (New-AzOpsScope -scope $Resource.ResourceId -StatePath $StatePath).statepath
            }
            else {
                Write-AzOpsMessage -LogLevel Error -LogString 'ConvertTo-AzOpsState.NoExportPath' -LogStringValues $Resource.GetType()
            }
        }
        else {
            $objectFilePath = $ExportPath
        }
        # Create folder structure if it doesn't exist
        if (-not (Test-Path -Path $objectFilePath)) {
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.File.Create' -LogStringValues $objectFilePath
            $null = New-Item -Path $objectFilePath -ItemType "file" -Force
        }
        else {
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.File.UseExisting' -LogStringValues $objectFilePath
        }

        # If export file path ends with parameter
        $generateTemplateParameter = $objectFilePath.EndsWith('.parameters.json') ? $true : $false
        Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplateParameter' -LogStringValues "$generateTemplateParameter"

        $resourceType = $null
        switch ($Resource) {
            { $_.ResourceType } {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.ResourceType' -LogStringValues "$($Resource.ResourceType)"
                $resourceType = $_.ResourceType
                break
            }
            # Management Groups
            { $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] -or
                $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupChildInfo] } {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -LogStringValues "$($_.GetType())"
                if ($_.Type -eq "/subscriptions") {
                    $resourceType = 'Microsoft.Management/managementGroups/subscriptions'
                    break
                }
                else {
                    $resourceType = 'Microsoft.Management/managementGroups'
                    break
                }
            }
            # Subscriptions
            { $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] } {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -LogStringValues "$($_.GetType())"
                $resourceType = 'Microsoft.Subscription/subscriptions'
                if (-not $Resource.Type) {
                    $Resource | Add-Member -NotePropertyName Type -NotePropertyValue $resourceType
                }
                break
            }
            # Resource Groups
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] } {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -LogStringValues "$($_.GetType())"
                $resourceType = 'Microsoft.Resources/resourceGroups'
                break
            }
            # Resources - Controlled group for raw  objects
            { $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant] } {
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.PSObject' -LogStringValues "$($_.GetType())"
                break
            }
            { $_.type } {
                if ( $_.type -eq 'Microsoft.Resources/subscriptions/resourceGroups') {
                    $resourceType = 'Microsoft.Resources/resourceGroups'
                }
                else {
                    $resourceType = $_.type
                }
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.ResourceType' -LogStringValues $resourceType
                break
            }
            Default {
                Write-AzOpsMessage -LogLevel Warning -LogString 'ConvertTo-AzOpsState.ObjectType.Resolved.Generic' -LogStringValues "$($_.GetType())"
                break
            }
        }
        if ($resourceType) {
            $providerNamespace = ($resourceType -split '/' | Select-Object -First 1)
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ProviderNamespace' -LogStringValues $providerNamespace

            if (($resourceType -split '/').Count -eq 2) {
                $resourceTypeName = (($resourceType -split '/', 2) | Select-Object -Last 1)
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ResourceTypeName' -LogStringValues $resourceTypeName

                $resourceApiTypeName = (($resourceType -split '/', 2) | Select-Object -Last 1)
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ResourceApiTypeName' -LogStringValues $resourceApiTypeName
            }

            if (($resourceType -split '/').Count -eq 3) {
                $resourceTypeName = ((($resourceType -split '/', 3) | Select-Object -Last 2) -join '/')
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ResourceTypeName' -LogStringValues $resourceTypeName

                $resourceApiTypeName = (($resourceType -split '/', 3) | Select-Object -Index 1)
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ResourceApiTypeName' -LogStringValues $resourceApiTypeName
            }

            $jqRemoveTemplate = Get-AzOpsTemplateFile -File (Join-Path $providerNamespace -ChildPath "$resourceTypeName.jq") -Fallback "generic.jq"

            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Jq.Remove' -LogStringValues $jqRemoveTemplate
            # If we were able to determine resourceType, apply filter and write template or template parameter files based on output filename.
            $object = $Resource | ConvertTo-Json -Depth 100 -EnumsAsStrings | jq -r -f $jqRemoveTemplate | ConvertFrom-Json

            if ($ReturnObject) {
                return $object
            }
            else {
                if ($generateTemplateParameter) {
                    #region Generating Template Parameter
                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplateParameter'

                    $jqJsonTemplate = Get-AzOpsTemplateFile -File (Join-Path $providerNamespace -ChildPath "$resourceTypeName.parameters.jq") -Fallback "template.parameters.jq"

                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Jq.Template' -LogStringValues $jqJsonTemplate
                    $object = ($object | ConvertTo-Json -Depth 100 -EnumsAsStrings | jq -r '--sort-keys' | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
                    #endregion
                }
                else {
                    #region Generating Template
                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate' -LogStringValues "$true"
                    $jqJsonTemplate = Get-AzOpsTemplateFile -File (Join-Path $providerNamespace -ChildPath "$resourceTypeName.template.jq") -Fallback "template.jq"
                    Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Jq.Template' -LogStringValues $jqJsonTemplate
                    $object = ($object | ConvertTo-Json -Depth 100 -EnumsAsStrings | jq -r '--sort-keys' | jq -r -f $jqJsonTemplate | ConvertFrom-Json)
                    #endregion

                    #region Replace Resource Type and API Version
                    if (
                        ($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }) -and
                        (($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }).ResourceTypes | Where-Object { $_.ResourceTypeName -eq $resourceApiTypeName })
                    ) {
                        $apiVersions = (($Script:AzOpsResourceProvider | Where-Object { $_.ProviderNamespace -eq $providerNamespace }).ResourceTypes | Where-Object { $_.ResourceTypeName -eq $resourceApiTypeName }).ApiVersions

                        # Handle GA/Preview API versions
                        $gaApiVersion = $apiVersions | Where-Object {$_ -match '^\d{4}\-(0[1-9]|1[012])\-(0[1-9]|[12][0-9]|3[01])$'} | Sort-Object -Descending
                        $preApiVersion = $apiVersions | Where-Object {$_ -notmatch '^\d{4}\-(0[1-9]|1[012])\-(0[1-9]|[12][0-9]|3[01])$'} | Sort-Object -Descending

                        if ($null -eq $gaApiVersion) {
                            $apiVersion = $preApiVersion | Select-Object -First 1
                        } else {
                            $apiVersion = $gaApiVersion | Select-Object -First 1
                        }
                        Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ApiVersion' -LogStringValues $resourceType, $apiVersion
                        $object.resources[0].apiVersion = $apiVersion
                        $object.resources[0].type = $resourceType
                    }
                    else {
                        Write-AzOpsMessage -LogLevel Warning -LogString 'ConvertTo-AzOpsState.GenerateTemplate.NoApiVersion' -LogStringValues $resourceType
                    }
                    #endregion

                    #region Append Name for child resource
                    # [Patch] Temporary until mangementGroup() is fully implemented
                    if ($resourceType -eq "Microsoft.Management/managementGroups/subscriptions") {
                        $resourceName = (((New-AzOpsScope -Scope $Resource.Id).ManagementGroup) + "/" + $Resource.Name)
                        $object.resources[0].name = $resourceName
                        Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.GenerateTemplate.ChildResource' -LogStringValues $resourceName
                    }
                    #endregion

                }
                Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Exporting' -LogStringValues $objectFilePath
                ConvertTo-Json -InputObject $object -Depth 100 -EnumsAsStrings | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force
            }
        }
        else {
            Write-AzOpsMessage -LogLevel Debug -LogString 'ConvertTo-AzOpsState.Exporting.Default' -LogStringValues $objectFilePath
            if ($ReturnObject) { return $Resource }
            else {
                ConvertTo-Json -InputObject $Resource -Depth 100 -EnumsAsStrings | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force
            }
        }
    }
}