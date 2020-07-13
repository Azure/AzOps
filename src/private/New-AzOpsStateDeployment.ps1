<#
.SYNOPSIS
    This cmdlet processes AzOpsState changes and takes appropriate action by invoking ARM deployment and limited set of imperative operations required by platform that is currently not supported in ARM.
.DESCRIPTION
    This cmdlet invokes ARM deployment by calling New-AzDeployment* command at appropriate scope mapped to tenant, Management Group, Subscription or resource group in AzOpsState folder.
        1) Filename must end with <template-name>.parameters.json
        2) This cmdlet will look for <template-name>.json in same directory and use that template if found.
        3) If no template file is found, it will use default template\template.json for supported resource types.

    This cmdlet invokes following imperative operations that are not supported in ARM.
        1) Subscription Creation with Enterprise Enrollment - Subscription will be created if not found in Azure where service principle have access. Subscription will also be moved to the Management Group.

        2) Resource providers registration until ARM support is available.  Following format is used for *.providerfeatures.json
            [
                {
                    "ProviderNamespace":  "Microsoft.Security",
                    "RegistrationState":  "Registered"
                }
            ]
        3) Resource provider features registration until ARM support is available.  Following format is used for *.resourceproviders.json
            [
                {
                    "FeatureName":  "",
                    "ProviderName":  "",
                    "RegistrationState":  ""
                }
            ]
.EXAMPLE
    # Invoke ARM Template Deployment
    New-AzOpsStateDeployment -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\.AzState\Microsoft.Management-managementGroups_contoso.parameters.json'
.EXAMPLE
    # Invoke Subscription Creation
    New-AzOpsStateDeployment -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\platform\connectivity\subscription.json'
.EXAMPLE
    # Invoke provider features registration
    New-AzOpsStateDeployment -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\platform\connectivity\providerfeatures.json'
.EXAMPLE
    # Invoke resource providers registration
    New-AzOpsStateDeployment -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\platform\connectivity\resourceproviders.json'
.INPUTS
    Filename
.OUTPUTS
    None
#>
function New-AzOpsStateDeployment {

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsEnrollmentAccountPrincipalName')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsOfferType')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsDefaultDeploymentRegion')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsMainTemplate')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateScript( { Test-Path $_ })]
        $filename
    )

    begin {}

    process {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsStateDeployment" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "New-AzOpsStateDeployment for $filename"
        $Item = Get-Item -Path $filename
        $scope = New-AzOpsScope -path $Item

        if ($scope.type) {
            $templateParametersJson = Get-Content $filename | ConvertFrom-json

            if ($scope.type -eq 'subscriptions' -and $filename -match '/*.subscription.json$') {

                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Upsert subscriptions for $filename"
                $subscription = Get-AzSubscription -SubscriptionName $scope.subscriptionDisplayName -ErrorAction SilentlyContinue

                if ($null -eq $subscription) {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Creating new Subscription"

                    if ((Get-AzEnrollmentAccount)) {
                        if ($global:AzOpsEnrollmentAccountPrincipalName) {
                            Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Querying EnrollmentAccountObjectId for $($global:AzOpsEnrollmentAccountPrincipalName)"
                            $EnrollmentAccountObjectId = (Get-AzEnrollmentAccount | Where-Object -FilterScript { $_.PrincipalName -eq $global:AzOpsEnrollmentAccountPrincipalName }).ObjectId
                        }
                        else {
                            Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Using first enrollement account"
                            $EnrollmentAccountObjectId = (Get-AzEnrollmentAccount)[0].ObjectId
                        }

                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "EnrollmentAccountObjectId: $EnrollmentAccountObjectId"

                        if ($PSCmdlet.ShouldProcess("Create new Subscription?")) {
                            $subscription = New-AzSubscription -Name $scope.Name -OfferType $global:AzOpsOfferType -EnrollmentAccountObjectId $EnrollmentAccountObjectId
                        }
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Creating new Subscription Success!"

                        $ManagementGroupName = $scope.managementgroup
                        if ($PSCmdlet.ShouldProcess("Move Subscription to Management Group?")) {
                            New-AzManagementGroupSubscription -GroupName $ManagementGroupName -SubscriptionId $subscription.SubscriptionId
                        }
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Assigned Subscription to Management Group $ManagementGroupName"
                    }
                    else {
                        Write-AzOpsLog -Level Error -Topic "New-AzOpsStateDeployment" -Message "No Azure Enrollment account found for current Azure context"
                        Write-AzOpsLog -Level Error -Topic "New-AzOpsStateDeployment" -Message "Create new Azure role assignment for service principle used for pipeline: New-AzRoleAssignment -ObjectId <application-Id> -RoleDefinitionName Owner -Scope /providers/Microsoft.Billing/enrollmentAccounts/<object-Id>"
                    }
                }
                else {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Existing Subscription found with ID: $($subscription.Id) Name: $($subscription.Name)"
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Checking if it is in desired Management Group"
                    $ManagementGroupName = $scope.managementgroup
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Assigning Subscription to Management Group $ManagementGroupName"
                    if ($PSCmdlet.ShouldProcess("Move Subscription to Management Group?")) {
                        New-AzManagementGroupSubscription -GroupName $ManagementGroupName -SubscriptionId $subscription.SubscriptionId
                    }

                }
            }
            if ($scope.type -eq 'subscriptions' -and $filename -match '/*.providerfeatures.json$') {
                Register-AzOpsProviderFeature -filename $filename -scope $scope
            }
            if ($scope.type -eq 'subscriptions' -and $filename -match '/*.resourceproviders.json$') {

                Register-AzOpsResourceProvider -filename $filename -scope $scope
            }
            if ($filename -match '/*.parameters.json$') {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Template deployment"

                $MainTemplateSupportedTypes = @(
                    "Microsoft.Resources/resourceGroups",
                    "Microsoft.Authorization/policyAssignments",
                    "Microsoft.Authorization/policyDefinitions",
                    "Microsoft.Authorization/PolicySetDefinitions",
                    "Microsoft.Authorization/roleDefinitions",
                    "Microsoft.Authorization/roleAssignments",
                    "Microsoft.PolicyInsights/remediations",
                    "Microsoft.ContainerService/ManagedClusters",
                    "Microsoft.KeyVault/vaults",
                    "Microsoft.Network/virtualWans",
                    "Microsoft.Network/virtualHubs",
                    "Microsoft.Network/virtualNetworks",
                    "Microsoft.Network/azureFirewalls",
                    "/providers/Microsoft.Management/managementGroups",
                    "/subscriptions"
                )

                if (($scope.subscription) -and (Get-AzContext).Subscription.Id -ne $scope.subscription) {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Switching Subscription context from $($(Get-AzContext).Subscription.Name) to $scope.subscription "
                    Set-AzContext -SubscriptionId $scope.subscription
                }

                $templatename = (Get-Item $filename).BaseName.Replace('.parameters', '.json')
                $templatePath = (Join-Path (Get-Item $filename).Directory.FullName -ChildPath $templatename )
                if (Test-Path $templatePath) {
                    $templatePath = (Join-Path (Get-Item $filename).Directory.FullName -ChildPath $templatename )
                }
                else {

                    $effectiveResourceType = ''
                    # Check if generic template is supporting the resource type for the deployment.
                    if ((Get-Member -InputObject $templateParametersJson.parameters.input.value -Name ResourceType)) {
                        $effectiveResourceType = $templateParametersJson.parameters.input.value.ResourceType
                    }
                    elseif ((Get-Member -InputObject $templateParametersJson.parameters.input.value -Name Type)) {
                        $effectiveResourceType = $templateParametersJson.parameters.input.value.Type
                    }
                    else {
                        $effectiveResourceType = ''
                    }
                    if ($effectiveResourceType -and ($MainTemplateSupportedTypes -Contains $effectiveResourceType)) {
                        $templatePath = $global:AzOpsMainTemplate
                    }
                }

                if (Test-Path $templatePath) {
                    $deploymentName = (Get-Item $filename).BaseName.replace('.parameters', '').Replace(' ', '_')

                    if ($deploymentName.Length -gt 64) {
                        $deploymentName = $deploymentName.SubString($deploymentName.IndexOf('-') + 1)
                    }
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Template is $templatename / $templatepath and Deployment Name is $deploymentName"
                    if ($scope.resourcegroup) {
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Starting [Resource Group] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                        Test-AzResourceGroupDeployment -ResourceGroupName $scope.resourcegroup -TemplateFile $templatePath -TemplateParameterFile $filename -OutVariable templateErrors
                        if (-not $templateErrors -and $PSCmdlet.ShouldProcess("Start Resource Group Deployment?")) {
                            New-AzResourceGroupDeployment -ResourceGroupName $scope.resourcegroup -TemplateFile $templatePath -TemplateParameterFile $filename -Name $deploymentName
                        }
                        else {
                            Write-AzOpsLog -Level Error -Topic "New-AzOpsStateDeployment" -Message "Resource Group [$($scope.resourcegroup)] not found. Unable to initiate deployment."
                        }
                    }
                    elseif ($scope.subscription -and $PSCmdlet.ShouldProcess("Start Subscription Deployment?")) {
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Starting [Subscription] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                        New-AzSubscriptionDeployment -Location $global:AzOpsDefaultDeploymentRegion -TemplateFile $templatePath -TemplateParameterFile $filename -Name $deploymentName
                    }
                    elseif ($scope.managementgroup -and $PSCmdlet.ShouldProcess("Start Management Group Deployment?")) {
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Starting [Management Group] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                        New-AzManagementGroupDeployment -ManagementGroupId $scope.managementgroup -Name $deploymentName  -Location  $global:AzOpsDefaultDeploymentRegion -TemplateFile $templatePath -TemplateParameterFile $filename
                    }
                    elseif ($scope.type -eq 'root' -and $PSCmdlet.ShouldProcess("Start Tenant Deployment?")) {
                        Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Starting [Tenant] deployment in [$($global:AzOpsDefaultDeploymentRegion)]"
                        New-AzTenantDeployment -Name $deploymentName  -Location  $global:AzOpsDefaultDeploymentRegion -TemplateFile $templatePath -TemplateParameterFile $filename
                    }
                }
            }
            else {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsStateDeployment" -Message "Template Path for $templatePath for $filename not found"
            }
        }
        else {
            Write-AzOpsLog -Level Warning -Topic "New-AzOpsStateDeployment" -Message "Unable to determine scope type for $filename"
        }

    }

    end {}

}