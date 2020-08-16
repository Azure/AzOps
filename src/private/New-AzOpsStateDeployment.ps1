<#
.SYNOPSIS
    This cmdlet processes AzOpsState changes and takes appropriate action by invoking ARM deployment and limited set of imperative operations required by platform that is currently not supported in ARM.
.DESCRIPTION

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
        }
        else {
            Write-AzOpsLog -Level Warning -Topic "New-AzOpsStateDeployment" -Message "Unable to determine scope type for $filename"
        }
    }
    end {}
}