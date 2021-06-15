function New-Deployment {

    [CmdletBinding()]
    param ()

    begin {
        function Connect-Account {
            process {
                Write-PSFMessage -Level Verbose -Message "Validating context"
                $tenant = (Get-AzContext -ListAvailable -ErrorAction SilentlyContinue).Tenant.Id
                if ($tenant -inotcontains "$($env:ARM_TENANT_ID)") {
                    Write-PSFMessage -Level Verbose -Message "Authenticating session"
                    if ($env:USER -eq "vsts") {
                        # Platform: Azure Pipelines
                        $credential = New-Object PSCredential -ArgumentList $env:ARM_CLIENT_ID, (ConvertTo-SecureString -String $env:ARM_CLIENT_SECRET -AsPlainText -Force)
                        $null = Connect-AzAccount -TenantId $env:ARM_TENANT_ID -ServicePrincipal -Credential $credential -SubscriptionId $env:ARM_SUBSCRIPTION_ID -WarningAction SilentlyContinue
                    }
                }
                else {
                    Write-PSFMessage -Level Verbose -Message "Setting context"
                    $null = Set-AzContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
                }
            }
        }
    }

    process {
        Write-PSFMessage -Level Verbose -Message "Deploying test environment"

        if ($null -eq $env:ARM_TENANT_ID) {
            Write-PSFMessage -Level Critical -Message "Unset variable ARM_TENANT_ID"
            continue
        }
        if ($null -eq $env:ARM_SUBSCRIPTION_ID) {
            Write-PSFMessage -Level Critical -Message "Unset variable ARM_SUBSCRIPTION_ID"
            continue
        }

        $tenantId = $env:ARM_TENANT_ID
        $subscriptionId = $env:ARM_SUBSCRIPTION_ID
        $managementGroupName = "Tests"
        $resourceGroupName = "Application-0"

        Connect-Account

        $repositoryRoot = (Resolve-Path "$PSScriptRoot/..").Path
        $testRoot = (Join-Path -Path $repositoryRoot -ChildPath "tests")
        $templateFile = Join-Path -Path $testroot -ChildPath "artifacts/azuredeploy.jsonc"

        $templateParameters = @{
            "tenantId"            = "$tenantId"
            "subscriptionId"      = "$subscriptionId"
            "managementGroupName" = "$managementGroupName"
            "resourceGroupName"   = "$resourceGroupName"
        }
        $params = @{
            ManagementGroupId       = "$tenantId"
            Name                    = "AzOps.Tests"
            TemplateFile            = "$templateFile"
            TemplateParameterObject = $templateParameters
            Location                = "northeurope"
        }

        Write-PSFMessage -Level Verbose -Message "Creating Management Group structure"
        try {
            New-AzManagementGroupDeployment @params
        }
        catch {
            Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
            continue
        }

    }

}
function Remove-Deployment {

    [CmdletBinding()]
    param()

    begin {
        function Connect-Account {
            process {
                Write-PSFMessage -Level Verbose -Message "Validating context"
                $tenant = (Get-AzContext -ListAvailable -ErrorAction SilentlyContinue).Tenant.Id
                if ($tenant -inotcontains "$($env:ARM_TENANT_ID)") {
                    Write-PSFMessage -Level Verbose -Message "Authenticating session"
                    if ($env:USER -eq "vsts") {
                        # Platform: Azure Pipelines
                        $credential = New-Object PSCredential -ArgumentList $env:ARM_CLIENT_ID, (ConvertTo-SecureString -String $env:ARM_CLIENT_SECRET -AsPlainText -Force)
                        $null = Connect-AzAccount -TenantId $env:ARM_TENANT_ID -ServicePrincipal -Credential $credential -SubscriptionId $env:ARM_SUBSCRIPTION_ID -WarningAction SilentlyContinue
                    }
                }
                else {
                    Write-PSFMessage -Level Verbose -Message "Setting context"
                    $null = Set-AzContext -TenantId $env:ARM_TENANT_ID -SubscriptionId $env:ARM_SUBSCRIPTION_ID
                }
            }
        }
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
                            Write-PSFMessage -Level Verbose -Message "Moving $($_.Name)"
                            # Move Subscription resource to Tenant Root Group
                            New-AzManagementGroupSubscription -GroupId $RootName -SubscriptionId $_.Name -WarningAction SilentlyContinue
                        }
                    }
                }

                Write-PSFMessage -Level Verbose -Message "Removing $($DisplayName)"
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
                Write-PSFMessage -Level Verbose -Message "Setting Context: $($SubscriptionName)"
                $null = Set-AzContext -SubscriptionName $subscriptionName

                $ResourceGroupNames | ForEach-Object {
                    Write-PSFMessage -Level Verbose -Message "Removing Resource Group: $($_)"
                    Remove-AzResourceGroup -Name $_ -Force
                }
            }

        }
    }

    process {
        Write-PSFMessage -Level Verbose -Message "Removing test environment"

        if ($null -eq $env:ARM_TENANT_ID) {
            Write-PSFMessage -Level Critical -Message "Unset variable ARM_TENANT_ID"
            continue
        }
        if ($null -eq $env:ARM_SUBSCRIPTION_ID) {
            Write-PSFMessage -Level Critical -Message "Unset variable ARM_SUBSCRIPTION_ID"
            continue
        }

        $tenantId = $env:ARM_TENANT_ID
        $subscriptionId = $env:ARM_SUBSCRIPTION_ID
        $managementGroupName = "Test"
        $resourceGroupName = "Application-0"

        Connect-Account

        $managementGroup = Get-AzManagementGroup | Where-Object DisplayName -eq $managementGroupName
        if ($managementGroup) {
            Write-PSFMessage -Level Verbose -Message "Removing Management Group structure"
            Remove-ManagementGroups -DisplayName $managementGroupName -Name $managementGroup.Name -RootName $tenantId
        }

        $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
        if ($resourceGroup) {
            Write-PSFMessage -Level Verbose -Message "Removing Resource Groups"
            $subscription = Get-AzSubscription -SubscriptionId $subscriptionId
            Remove-ResourceGroups -SubscriptionName $subscription.Name -ResourceGroupNames @($resourceGroup.ResourceGroupName)
        }
    }

}