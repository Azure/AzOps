﻿#region setupEnvironment
Write-PSFMessage -Level Verbose -Message "Initializing functional test environment" -FunctionName "BeforeAll"
Set-PSFConfig -FullName AzOps.Core.DefaultDeploymentRegion -Value "northeurope"

# Suppress the breaking change warning messages in Azure PowerShell
Set-Item -Path  Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

$script:repositoryRoot = (Resolve-Path "$global:testroot/../..").Path
$script:tenantId = $env:ARM_TENANT_ID
$script:subscriptionId = $env:ARM_SUBSCRIPTION_ID

# Validate that the runtime variables are set as they are used to authenticate the Azure session.

if ($null -eq $script:tenantId) {
    Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_TENANT_ID"
    throw
}
if ($null -eq $script:subscriptionId) {
    Write-PSFMessage -Level Critical -Message "Unable to validate environment variable ARM_SUBSCRIPTION_ID"
    throw
}

# Ensure PowerShell has an authenticate Azure Context which the tests can run within and generate data as needed

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
    $null = Set-AzContext -TenantId $script:tenantId -SubscriptionId $script:subscriptionId
}

# Deploy the Azure environment based upon prefined resource templates which will generate a matching file system hierachy

Write-PSFMessage -Level Verbose -Message "Getting functional test objects based on structure" -FunctionName "BeforeAll"
$script:functionalTestObjectPath = Join-Path $global:testroot -ChildPath "functional"
$script:testObjects = Get-ChildItem -Path $script:functionalTestObjectPath -Recurse -Filter "deploy.ps1" -File
Write-PSFMessage -Level Verbose -Message "Found $($script:testObjects.count) functional test objects to deploy" -FunctionName "BeforeAll"
try {
    $script:scriptPath = (Resolve-Path "$global:testroot/../../scripts").Path
    . (Join-Path -Path $script:scriptPath -ChildPath New-AzOpsTestsDeploymentHelper.ps1)
    Write-PSFMessage -Level Verbose -Message "Executing deploy of functional test objects" -FunctionName "BeforeAll"
    $script:functionalTestDeploy = $script:testObjects.VersionInfo.FileName | ForEach-Object {
        Write-PSFMessage -Level Verbose -Message "Executing deploy of functional test object: $_" -FunctionName "BeforeAll"
        & $_
    }
    # Pause for resource consistency
    Start-Sleep -Seconds 120
}
catch {
    Write-PSFMessage -Level Warning -String "Executing functional test object failed"
}

# Ensure that the root directories does not exist before running tests.

Write-PSFMessage -Level Verbose -Message "Testing for root directory existence" -FunctionName "BeforeAll"
$generatedRoot = Join-Path -Path $script:repositoryRoot -ChildPath "root"
if (Test-Path -Path $generatedRoot) {
    Write-PSFMessage -Level Verbose -Message "Removing root directory" -FunctionName "BeforeAll"
    Remove-Item -Path $generatedRoot -Recurse
}

# Invoke the Invoke-AzOpsPull function to generate the scope data which can be tested against to ensure structure is correct and data model hasn't changed.

Set-PSFConfig -FullName AzOps.Core.SubscriptionsToIncludeResourceGroups -Value $script:subscriptionId
Set-PSFConfig -FullName AzOps.Core.SkipChildResource -Value $false
Set-PSFConfig -FullName AzOps.Core.SkipPim -Value $false
$deploymentLocationId = (Get-FileHash -Algorithm SHA256 -InputStream ([IO.MemoryStream]::new([byte[]][char[]](Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion')))).Hash.Substring(0, 4)

Write-PSFMessage -Level Verbose -Message "Generating folder structure" -FunctionName "BeforeAll"
try {
    Initialize-AzOpsEnvironment
    Invoke-AzOpsPull -SkipRole:$false -SkipPolicy:$false -SkipResource:$false -SkipResourceGroup:$false
}
catch {
    Write-PSFMessage -Level Critical -Message "Initialize failed" -Exception $_.Exception
    throw
}

# Collect Pulled Files
$script:functionalTestFilePaths = (Get-ChildItem -Path $generatedRoot -Recurse)

# Return Output
$script:return = [PSCustomObject]@{
    functionalTestDeploy    = $script:functionalTestDeploy
    functionalTestFilePaths = $script:functionalTestFilePaths
}
return $script:return
#endregion setupEnvironment