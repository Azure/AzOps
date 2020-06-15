<#
.SYNOPSIS
    The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
.DESCRIPTION
    The cmdlet converts Azure resources (Resources/ResourceGroups/Policy/PolicySet/PolicyAssignments/RoleAssignment/Definition) to the AzOps state format and exports them to the file structure.
    It is normally executed and orchestrated through the Initialize-AzOpsRepository cmdlet. As most of the AzOps-cmdlets, it is dependant on the AzOpsAzManagementGroup and AzOpsSubscriptions variables.
    $Global:AzopsStateConfig with custom json schema are used to determine what properties that should be excluded from different resource types as well as if the json documents should be ordered or not.
.EXAMPLE
    #Export custom policy definition to the AzOps StatePath
    Initialize-AzOpsGlobalVariables -Verbose
    $policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
    ConvertTo-AzOpsState -Resource $policy
.EXAMPLE
    #Serialize custom policy definition to the AzOps format, return object instead of export file
    Initialize-AzOpsGlobalVariables -Verbose
    $policy = Get-AzPolicyDefinition -Custom | Select-Object -Last 1
    ConvertTo-AzOpsState -Resource $policy -ReturnObject
    Name                           Value
    ----                           -----
    $schema                        http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#
    contentVersion                 1.0.0.0
    parameters                     {input}
.INPUTS
    Resource
.OUTPUTS
    Resource in AzOpsState json format or object returned as [PSCustomObject] depending on parameters used
#>
function ConvertTo-AzOpsState {
    
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        #Object with resource as input
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias('MG', 'Role', 'Assignment', 'CustomObject', 'ResourceGroup')]
        $Resource,
        #ExportPath is used if resource needs to be exported to other path than the AzOpsScope path
        [Parameter(Mandatory = $false)]
        $ExportPath = '',
        #Used if to return object in pipeline instead of exporting file
        [Parameter(Mandatory = $false)]
        [switch]$ReturnObject,
        #Used in cases you want to return the template without the custom parameters json schema
        [Parameter(Mandatory = $false)]
        [switch]$ExportRawTemplate
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
        #Construct base json
        $parametersJson = [ordered]@{
            '$schema'        = 'http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#'
            'contentVersion' = "1.0.0.0"
            'parameters'     = [ordered]@{
                'input' = [ordered]@{
                    'value' = $null
                }
            }
        }
        $ExcludedProperties = @{}
        #Fetch config json
        try {
            $ResourceConfig = (Get-Content -Path $Global:AzopsStateConfig) | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            throw "Cannot load $Global:AzOpsStateConfig, is the json schema valid or is the variable initialization not run yet?`r`n$_"
        }

        $Object = $Resource
        #Determine objecttype and set target AzOpsScope statepath properties to omit for the export.
        switch ($Resource) {
            #Tenant
            { $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureTenant] } {
                Write-Verbose -Message " - Object is Tenant"
                $ResourceConfig = $ResourceConfig.Values.tenant
                break
            }
            #Management Groups
            { $_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroup] } {
                Write-Verbose -Message " - Object is Management Group"
                $objectFilePath = (New-AzOpsScope -scope $object.id).statepath
                $ResourceConfig = $ResourceConfig.Values.managementGroup
                break
            }
            #Role Definitions
            { $_ -is [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition] } {
                Write-Verbose -Message " - Object is Role Definition"
                $objectFilePath = (New-AzOpsScope -scope "$($object.AssignableScopes[0])/providers/Microsoft.Authorization/roleDefinitions/$($role.Id)").statepath
                $ResourceConfig = $ResourceConfig.Values.roleDefinition
                break
            }
            #Role Assignments
            { $_ -is [Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleAssignment] } {
                Write-Verbose -Message " - Object is Role Assignment"
                $objectFilePath = (New-AzOpsScope -scope $object.RoleAssignmentId).statepath
                $ResourceConfig = $ResourceConfig.Values.roleAssignment
                break
            }
            #Resources
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource] } {
                Write-Verbose -Message " - Object is Resource"
                $objectFilePath = (New-AzOpsScope -scope $object.ResourceId).statepath
                $ResourceConfig = $ResourceConfig.Values.resource
                break
            }
            #Resource Groups
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] } {
                Write-Verbose -Message " - Object is ResourceGroup"
                $objectFilePath = (New-AzOpsScope -scope $object.ResourceId).statepath
                $ResourceConfig = $ResourceConfig.Values.resourceGroup
                break
            }
            #Subscriptions
            { $_ -is [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription] } {
                Write-Verbose -Message " - Object is Subscription"
                $objectFilePath = (New-AzOpsScope -scope "/subscriptions/$($object.id)").statepath
                $ResourceConfig = $ResourceConfig.Values.subscription
                break
            }
            #Subscription from ManagementGroup Children
            { ($_ -is [Microsoft.Azure.Commands.Resources.Models.ManagementGroups.PSManagementGroupChildInfo] -and $_.Type -eq '/subscriptions') } {
                Write-Verbose -Message " - Object is Subscription"
                $objectFilePath = (New-AzOpsScope -scope $object.id).statepath
                $ResourceConfig = $ResourceConfig.Values.subscription
                break
            }
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyDefinition] } {
                Write-Verbose -Message " - Object is PsPolicyDefinition"
                $objectFilePath = (New-AzOpsScope -scope $object.ResourceId).statepath
                $object = ConvertTo-AzOpsObject -InputObject $object
                $ResourceConfig = $ResourceConfig.Values.policyDefinition
                break
            }
            #PsPolicySetDefinition
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicySetDefinition] } {
                Write-Verbose -Message " - Object is PsPolicySetDefinition"
                $objectFilePath = (New-AzOpsScope -scope $object.ResourceId).statepath
                $object = ConvertTo-AzOpsObject -InputObject $object
                $ResourceConfig = $ResourceConfig.Values.policySetDefinition
                break
            }
            #PsPolicyAssignment
            { $_ -is [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyAssignment] } {
                Write-Verbose -Message " - Object is PsPolicyAssignment"
                $objectFilePath = (New-AzOpsScope -scope $object.ResourceId).statepath
                $object = ConvertTo-AzOpsObject -InputObject $object
                $ResourceConfig = $ResourceConfig.Values.policyAssignment
                break
            }
            #If object wasn't determined and $ExportPath isn not defined, throw error
            'Default' {
                Write-Verbose -Message " - Generic object detected, ExportPath expected"
                #Setting the value here so that exclusion logic can be applied. In future we can remove this.
                $ResourceConfig = $ResourceConfig.Values.PSCustomObject
                if (-not($ExportPath)) {
                    throw "No export path found"
                }
                break
            }
        }
        #Set objectfilepath to ExportPath if specified
        if ($ExportPath) {
            $objectFilePath = $ExportPath
            Write-Verbose -Message " - ExportPath is $ExportPath"
        }
        # #Load default properties to exclude if defined
        if ("excludedProperties" -in $ResourceConfig.Keys) {
            $ExcludedProperties = $ResourceConfig.excludedProperties.default
        }

        Write-Verbose -Message " - Statepath is $objectFilePath"
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        if ($null -ne $object) {
            #Create target file object if it doesn't exist
            if ($objectFilePath -and -not(Test-Path $objectFilePath)) {
                Write-Verbose -Message " - AzOpsState File $objectFilePath do not exist. Creating New file."
                New-Item -Path $objectFilePath -ItemType "file" -Force | Out-Null
            }
            #Convert resource object to json and export to the object filepath
            #Check if object has to be ordered
            if ("orderObject" -in $ResourceConfig -and ($true -eq $ResourceConfig.orderObject)) {
                $object = ConvertTo-AzOpsObject -InputObject $object -OrderObject
                Write-Verbose -Message " - Ordered object"
            }

            #Check if Resource has to be generalized
            if ($env:GeneralizeTemplates -eq 1) {
                #Preserve Original Template before manipulating anything
                #Only export original resource if generalize excluded properties exist
                if ("excludedProperties" -in $ResourceConfig.Keys) {
                    #Set excludedproperties variable to generalize instead of default
                    $ExcludedProperties = ''
                    $ExcludedProperties = $ResourceConfig.excludedProperties.generalize
                    #Export preserved file
                    if ($objectFilePath) {
                        $parametersJson.parameters.input.value = $object
                        #ExportPath for the original state file
                        $originalFilePath = $objectfilepath -replace ".parameters.json", ".parameters.json.origin"
                        Write-Verbose -Message " - Exporting original resource to $originalFilePath"
                        ConvertTo-Json -InputObject $parametersJson -Depth 100 | Out-File -FilePath ([WildcardPattern]::Escape($originalFilePath)) -Encoding utf8 -Force
                    }
                }
            }

            #Iterate through all properties to exclude from object
            foreach ($ExProperty in $ExcludedProperties.Keys) {
                #Test if Object contains parent property first
                if (Get-Member -InputObject $object -Name $ExProperty) {
                    #Find child properties in exclusion hashtable
                    $ChildProperties = $ExcludedProperties.$ExProperty
                    #If subproperties exist, loop through and adjust properties accordingly
                    if ($ChildProperties -is [System.Collections.Hashtable]) {
                        $ChildProperties.Keys | ForEach-Object -Process {
                            $Value = $ChildProperties.$_
                            #Remove property if value is set to "Remove"
                            if ($value -eq "Remove") {
                                $TmpProperties = $object.$ExProperty | Select-Object -ExcludeProperty $_
                                $object.PsObject.Properties.Remove("$ExProperty")
                                Add-Member -InputObject $object -MemberType NoteProperty -Name $ExProperty -Value $TmpProperties -Force
                            }
                            else {
                                #If property exists on resource, update with new value
                                if ($object.$ExProperty.$_) {
                                    $object.$ExProperty.$_ = $value
                                }
                            }
                        }
                    }
                    else {
                        #Remove property if value is set to "Remove"
                        if ($ChildProperties -eq "Remove") {

                            if ($object.psobject.Properties.Item($ExProperty).IsSettable) {
                                $object.PsObject.Properties.Remove("$ExProperty")
                            }
                            else {
                                $object = $object | Select-Object -ExcludeProperty $ExProperty
                            }

                        }
                        else {
                            #If property exists on resource, update with new value
                            if ($object.$ExProperty) {
                                $object.$ExProperty = $ChildProperties
                            }
                        }
                    }
                }
            }

            #Export resource
            Write-Verbose -Message " - Exporting resource to $objectFilePath"
            if ('orderObject' -in $ResourceConfig) {
                $object = ConvertTo-AzOpsObject -InputObject $object -OrderObject
            }
            if ($env:ExportRawTemplate -eq 1 -or $PSBoundParameters["ExportRawTemplate"]) {
                if ($ReturnObject) {
                    #Return resource as object
                    Write-Output -InputObject $object
                }
                else {
                    #Export resource as raw json template
                    ConvertTo-Json -InputObject $object -Depth 100 | Out-File -FilePath ([WildcardPattern]::Escape($objectFilePath)) -Encoding utf8 -Force
                }
            }
            else {

                $parametersJson.parameters.input.value = $object
                if ($ReturnObject) {
                    #Return resource as object
                    Write-Output -InputObject $parametersJson
                }
                else {
                    #Export resource as AzOpsState parameter json
                    ConvertTo-Json -InputObject $parametersJson -Depth 100 | Out-File -FilePath ([WildcardPattern]::Escape($objectFilePath)) -Encoding utf8 -Force
                }
            }
        }
        else {
            Write-Warning -Message "No valid object"
        }
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}