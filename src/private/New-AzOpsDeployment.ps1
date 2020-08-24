<#
.SYNOPSIS
    This cmdlet processes AzOpsState changes and takes appropriate action by invoking ARM deployment and limited set of imperative operations required by platform that is currently not supported in ARM.
.DESCRIPTION
    This cmdlet invokes ARM deployment by calling New-AzDeployment* command at appropriate scope mapped to tenant, Management Group, Subscription or resource group in AzOpsState folder.
        1) Template File Path <template-name>.json
        2) Optional Parameter file that must end with <template-name>.parameters.json
        3) This cmdlet will look for <template-name>.json in same directory and use that template if found.
        4) If no template file is found, it will use default template\template.json for supported resource types.

.EXAMPLE
    # Invoke ARM Template Deployment
    New-AzOpsDeployment -templateParameterFilePath 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\.AzState\Microsoft.Management_managementGroups-contoso.parameters.json'
.INPUTS
    Filename
.OUTPUTS
    None
#>
function New-AzOpsDeployment {
    # The following SuppressMessageAttribute entries are used to suppress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsDefaultDeploymentRegion')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsMainTemplate')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ParameterSetName = "template", Mandatory = $false, ValueFromPipeline = $true)]
        [string]$deploymentName = "azops-template-deployment",
        [Parameter(Position = 0, ParameterSetName = "template", ValueFromPipeline = $true)]
        [ValidateScript( { Test-Path $_ })]
        [string]$templateFilePath,
        [Parameter(Position = 0, ParameterSetName = "template", Mandatory = $false, ValueFromPipeline = $true)]
        [string]$templateParameterFilePath,
        [Parameter(Position = 0, ParameterSetName = "template", Mandatory = $false, ValueFromPipeline = $true)]
        [string]$Mode = "Incremental"
    )
    begin {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsDeployment" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsDeployment" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        if ($templateParameterFilePath) {
            $scope = New-AzOpsScope -path $templateParameterFilePath
        }
        else {
            $scope = New-AzOpsScope -path $templateFilePath
        }
        if ($scope) {
            #Evaluate Deployment Scope
            if ($scope.resourcegroup) {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Attempting [Resource Group] deployment"
                if ((Get-AzContext).Subscription.Id -ne $scope.subscription) {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Switching Subscription context from $($(Get-AzContext).Subscription.Name) to $scope.subscription "
                    Set-AzContext -SubscriptionId $scope.subscription
                }
                $parameters = @{
                    'TemplateFile'                = $templateFilePath
                    'SkipTemplateParameterPrompt' = $true
                    'ResourceGroupName'           = $scope.resourcegroup
                }
                # Add Parameter file if specified
                if ($templateParameterFilePath) {
                    $parameters.Add('TemplateParameterFile', $templateParameterFilePath)
                }
                #Validate Template
                $results = Test-AzResourceGroupDeployment @parameters

                if (-not $results) {
                    $parameters.Add('Name', $deploymentName)
                    if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                        # Whatif Placeholder
                        New-AzResourceGroupDeployment @parameters -WhatIf -WhatIfResultFormat FullResourcePayloads
                    }
                    else {
                        New-AzResourceGroupDeployment @parameters
                    }
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "New-AzOpsDeployment" -Message "Template Validation Failed $($results.Message)"
                }
            }
            elseif ($scope.subscription) {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Attempting [Subscription] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                if ((Get-AzContext).Subscription.Id -ne $scope.subscription) {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Switching Subscription context from $($(Get-AzContext).Subscription.Name) to $scope.subscription "
                    Set-AzContext -SubscriptionId $scope.subscription
                }
                $parameters = @{
                    'TemplateFile'                = $templateFilePath
                    'location'                    = $global:AzOpsDefaultDeploymentRegion
                    'SkipTemplateParameterPrompt' = $true
                }
                # Add Parameter file if specified
                if ($templateParameterFilePath) {
                    $parameters.Add('TemplateParameterFile', $templateParameterFilePath)
                }
                #Validate Template
                $results = Test-AzSubscriptionDeployment @parameters

                if (-not $results) {
                    $parameters.Add('Name', $deploymentName)
                    if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                        # Whatif Placeholder
                        New-AzSubscriptionDeployment @parameters -WhatIf -WhatIfResultFormat FullResourcePayloads
                    }
                    else {
                        New-AzSubscriptionDeployment @parameters
                    }
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "New-AzOpsDeployment" -Message "Template Validation Failed $($results.Message)"
                }
            }
            elseif ($scope.managementGroup) {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Attempting [Management Group] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                $parameters = @{
                    'TemplateFile'                = $templateFilePath
                    'location'                    = $global:AzOpsDefaultDeploymentRegion
                    'ManagementGroupId'           = $scope.managementgroup
                    'SkipTemplateParameterPrompt' = $true
                }
                # Add Parameter file if specified
                if ($templateParameterFilePath) {
                    $parameters.Add('TemplateParameterFile', $templateParameterFilePath)
                }
                #Validate Template
                $results = Test-AzManagementGroupDeployment @parameters

                if (-not $results) {
                    $parameters.Add('Name', $deploymentName)
                    if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                        # Whatif Placeholder
                        New-AzManagementGroupDeployment @parameters -WhatIf
                    }
                    else {
                        New-AzManagementGroupDeployment @parameters
                    }
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "New-AzOpsDeployment" -Message "Template Validation Failed $($results.Message)"
                }
            }
            elseif ($scope.type -eq 'root' -and $scope.scope -eq '/') {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsDeployment" -Message "Attempting [Tenant Scope] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                $parameters = @{
                    'TemplateFile'                = $templateFilePath
                    'location'                    = $global:AzOpsDefaultDeploymentRegion
                    'SkipTemplateParameterPrompt' = $true
                }
                # Add Parameter file if specified
                if ($templateParameterFilePath) {
                    $parameters.Add('TemplateParameterFile', $templateParameterFilePath)
                }
                #Validate Template
                $results = Test-AzTenantDeployment @parameters

                if (-not $results) {
                    $parameters.Add('Name', $deploymentName)
                    if (-not ($PSCmdlet.ShouldProcess("Start ManagementGroup Deployment?"))) {
                        # Whatif Placeholder
                        New-AzTenantDeployment @parameters -WhatIf
                    }
                    else {
                        New-AzTenantDeployment @parameters
                    }
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "New-AzOpsDeployment" -Message "Template Validation Failed $($results.Message)"
                }
            }
            else {
                Write-AzOpsLog -Level Warning -Topic "New-AzOpsDeployment" -Message "Unable to determine scope type for Az deployment"
            }
        }
        else {
            Write-AzOpsLog -Level Warning -Topic "New-AzOpsDeployment" -Message "Unable to determine scope for templateFilePath: $templateFilePath and templateParameterFilePath: $templateParameterFilePath"
        }
    }
    end {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsDeployment" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}