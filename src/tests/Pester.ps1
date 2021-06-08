param (
    $TestGeneral = $true,

    $TestStatic = $true,

    $TestUnit = $false,

    $TestIntegration = $false,

    $TestFunctional = $false,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    $Output = "None",

    $Include = "*",

    $Exclude = @("Help.Tests.ps1")
)

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module AzOps -ErrorAction Ignore

Import-Module "$PSScriptRoot\..\AzOps.psd1" -Scope Global
Import-Module "$PSScriptRoot\..\AzOps.psm1" -Scope Global -Force

# Need to import explicitly so we can use the configuration class
Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test results folder"
$null = New-Item -Path "$PSScriptRoot\..\.." -Name results -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()
$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true

#region Functions
function New-Deployment {

    param ()

    process {
        Write-PSFMessage -Level Verbose -Message "Deploying test environment" -FunctionName "New-Deployment"

        $script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
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

        Write-PSFMessage -Level Verbose -Message "Validationg Azure context" -FunctionName "BeforeAll"
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
        $templateFile = Join-Path -Path $global:testroot -ChildPath "templates/azuredeploy.jsonc"
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
#endregion

#region Run General Tests
if ($TestGeneral) {
    Write-PSFMessage -Level Important -Message "Proceeding with general tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion

#region Run Static Tests
if ($TestStatic) {
    Write-PSFMessage -Level Important -Message "Proceeding with static tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\static" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion

#$global:__pester_data.ScriptAnalyzer | Out-Host

#region Run Unit Tests
if ($TestUnit) {
    Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "  Executing $($file.Name)"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion

#region Run Integration Tests
if ($TestIntegration) {
    Write-PSFMessage -Level Important -Message "Proceeding with integration tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\integration" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion

#region Run Functional Tests
if ($TestFunctional) {
    Write-PSFMessage -Level Important -Message "Proceeding with functional tests"
    New-Deployment
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functional" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [pscustomobject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
    Remove-Deployment
}
#endregion

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed!" }

if ($totalFailed -gt 0) {
    throw "$totalFailed / $totalRun tests failed!"
}