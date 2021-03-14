function ConvertTo-AzOpsState {

    <#
        .SYNOPSIS
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
        .DESCRIPTION
            The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
            It is normally executed and orchestrated through the Initialize-AzOpsRepository cmdlet. As most of the AzOps-cmdlets, it is dependant on the AzOpsAzManagementGroup and AzOpsSubscriptions variables.
            The state configuration file found at the location the 'AzOps.Core.StateConfig'-config points at with custom json schema are used to determine what properties that should be excluded from different resource types as well as if the json documents should be ordered or not.
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

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    begin {
        Write-PSFMessage -Level Debug -String 'ConvertTo-AzOpsState.Starting'

        #region Prepare Configuration Frame
        # Construct base json
        $parametersJson = [ordered]@{
            '$schema'        = 'http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#'
            'contentVersion' = "1.0.0.0"
            'parameters'     = [ordered]@{
                'input' = [ordered]@{
                    'value' = $null
                }
            }
        }
        # Fetch config json
        try {
            $resourceConfig = Get-Content -Path (Get-PSFConfigValue -FullName 'AzOps.Core.StateConfig') -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            Stop-PSFFunction -String 'ConvertTo-AzOpsState.StateConfig.Error' -StringValues (Get-PSFConfigValue -FullName 'AzOps.Core.StateConfig') -EnableException $true -Cmdlet $PSCmdlet -ErrorRecord $_
        }

        #endregion Prepare Configuration Frame
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

        if ($Resource.ResourceType -and $resourceConfig.resourceTypes[$Resource.ResourceType]) {
            #using ResourceType property to determine jq filter
            Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues "$($Resource.ResourceType)" -FunctionName 'ConvertTo-AzOpsState'
            $object = $Resource | ConvertTo-Json -Depth 100 | jq -r $resourceConfig.resourceTypes[$Resource.ResourceType].jq | ConvertFrom-Json
        }
        elseif ($resourceConfig.resourceTypes[$Resource.GetType().ToString()]) {
            #using PowerShell Object Type to determine jq filter
            Write-PSFMessage -String 'ConvertTo-AzOpsState.ObjectType.Resolved' -StringValues "$($Resource.GetType().ToString())" -FunctionName 'ConvertTo-AzOpsState'
            $object = $Resource | ConvertTo-Json -Depth 100 | jq -r $resourceConfig.resourceTypes[$Resource.GetType().ToString()].jq | ConvertFrom-Json
        }
        else {
            $object = $Resource | ConvertTo-Json -Depth 100 | jq -r $resourceConfig.resourceTypes['System.Management.Automation.PSCustomObject'].jq | ConvertFrom-Json
        }
        if (($null -ne $object) -and ($null -ne $objectFilePath)) {
            # Create target file object if it doesn't exist
            if (-not (Test-Path -Path $objectFilePath)) {
                Write-PSFMessage -String 'ConvertTo-AzOpsState.File.Create' -StringValues $objectFilePath
                $null = New-Item -Path $objectFilePath -ItemType "file" -Force
            }

            if ($ExportRawTemplate) {
                if ($ReturnObject) { $object }
                else { ConvertTo-Json -InputObject $object -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force }
            }
            else {
                $parametersJson.parameters.input.value = $object
                if ($ReturnObject) { $parametersJson }
                else { ConvertTo-Json -InputObject $parametersJson -Depth 100 | Set-Content -Path ([WildcardPattern]::Escape($objectFilePath)) -Encoding UTF8 -Force }
            }

            if ($ReturnObject) {
                return $object
            }
        }
        else {
            Write-PSFMessage -Level Error -String "ConvertTo-AzOpsState.File.JQError" -StringValues $Resource.GetType()
        }
    }
}