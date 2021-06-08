function New-Deployment {

    param ()

    process {
        Write-PSFMessage -Level Verbose -Message "Deploying test environment" -FunctionName "New-Deployment"

        $script:repositoryRoot = (Resolve-Path "$PSScriptRoot/..").Path
        $script:testRoot = (Join-Path -Path $script:repositoryRoot -ChildPath "tests")
        $script:tenantId = $env:ARM_TENANT_ID
        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        if ($null -eq $script:tenantId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_TENANT_ID"
            throw
        }
        if ($null -eq $script:subscriptionId) {
            Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_SUBSCRIPTION_ID"
            throw
        }

        Write-PSFMessage -Level Verbose -Message "Validating Azure context" -FunctionName "BeforeAll"
        $tenant = (Get-AzContext -ListAvailable -ErrorAction SilentlyContinue).Tenant.Id
        if ($tenant -inotcontains "$script:tenantId") {
            Write-PSFMessage -Level Verbose -Message "Authenticating Azure session" -FunctionName "BeforeAll"
            if ($env:USER -eq "vsts") {
                # Platform: Azure Pipelines
                $credential = New-Object PSCredential -ArgumentList $env:ARM_CLIENT_ID, (ConvertTo-SecureString -String $env:ARM_CLIENT_SECRET -AsPlainText -Force)
                $null = Connect-AzAccount -TenantId $script:tenantId -ServicePrincipal -Credential $credential -SubscriptionId $script:subscriptionId -WarningAction SilentlyContinue
            }
        }
        else {
            Set-AzContext -TenantId $script:tenantId -SubscriptionId $script:subscriptionId
        }

        Write-PSFMessage -Level Verbose -Message "Creating Management Group structure" -FunctionName "BeforeAll"
        $templateFile = Join-Path -Path $global:testroot -ChildPath "artifacts/azuredeploy.jsonc"
        $templateParameters = @{
            "tenantId"       = "$script:tenantId"
            "subscriptionId" = "$script:subscriptionId"
        }
        $params = @{
            ManagementGroupId       = "$script:tenantId"
            Name                    = "AzOps-Tests"
            TemplateFile            = "$templateFile"
            TemplateParameterObject = $templateParameters
            Location                = "northeurope"
        }
        try {
            New-AzManagementGroupDeployment @params
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
            throw
        }
    }

}
function Remove-Deployment {

    param()

    begin {
        function Remove-ManagementGroups {

            param (
                [Parameter()]
                [string]
                $DisplayName,

                [Parameter()]
                [string]
                $Name,

                [Parameter()]
                [string]
                $RootName
            )

            process {
                # Retrieve list of children within the provided Management Group Id
                $children = (Get-AzManagementGroup -GroupId $Name -Expand -Recurse -WarningAction SilentlyContinue).Children

                if ($children) {
                    $children | ForEach-Object {
                        if ($_.Type -eq "/providers/Microsoft.Management/managementGroups") {
                            # Invoke function again with Child resources
                            Remove-ManagementGroups -DisplayName $_.DisplayName -Name $_.Name -RootName $RootName
                        }
                        if ($_.Type -eq '/subscriptions') {
                            Write-PSFMessage -Level Verbose -Message "Moving Subscription: $($_.Name)" -FunctionName "AfterAll"
                            # Move Subscription resource to Tenant Root Group
                            New-AzManagementGroupSubscription -GroupId $RootName -SubscriptionId $_.Name -WarningAction SilentlyContinue
                        }
                    }
                }

                Write-PSFMessage -Level Verbose -Message "Removing Management Group: $($DisplayName)" -FunctionName "AfterAll"
                Remove-AzManagementGroup -GroupId $Name -WarningAction SilentlyContinue
            }

        }
        function Remove-ResourceGroups {

            param (
                [Parameter()]
                [string]
                $SubscriptionName,

                [Parameter()]
                [string[]]
                $ResourceGroupNames
            )

            process {
                Write-PSFMessage -Level Verbose -Message "Setting Context: $($SubscriptionName)" -FunctionName "AfterAll"
                Set-AzContext -SubscriptionName $subscriptionName

                $ResourceGroupNames | ForEach-Object {
                    Write-PSFMessage -Level Verbose -Message "Removing Resource Group: $($_)" -FunctionName "AfterAll"
                    Remove-AzResourceGroup -Name $_ -Force
                }
            }

        }
    }

    process {
        Write-PSFMessage -Level Verbose -Message "Removing test environment" -FunctionName "Remove-Deployment"

        $script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

        $managementGroup = Get-AzManagementGroup | Where-Object DisplayName -eq "Test"
        if ($managementGroup) {
            Write-PSFMessage -Level Verbose -Message "Removing Management Group structure" -FunctionName "AfterAll"
            Remove-ManagementGroups -DisplayName "Test" -Name $managementGroup.Name -RootName (Get-AzTenant).TenantId
        }

        $resourceGroup = Get-AzResourceGroup -Name "Application"
        if ($resourceGroup) {
            Write-PSFMessage -Level Verbose -Message "Removing Resource Groups" -FunctionName "AfterAll"
            $subscription = Get-AzSubscription -SubscriptionId $script:subscriptionId
            Remove-ResourceGroups -SubscriptionName $subscription.Name -ResourceGroupNames @($resourceGroup.ResourceGroupName)
        }
    }

}