$script:location = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
$script:deployTemplate = "deploy.bicep"

$script:resourceProvider = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-2]
$script:resourceType = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-1]

$script:templateFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$script:deployTemplate"

try {
    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting"
    $script:functionalTestDeploy = New-AzTenantDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -Location $script:location
    New-Variable -Name (($script:resourceType) + 'FunctionalTestDeploy') -Value $script:functionalTestDeploy -Scope Global -Force

    $script:timeOutMinutes = 30
    $script:mgmtRun = "Run"

    While ($script:mgmtRun -eq "Run") {
        Write-PSFMessage -Level Verbose -Message "Waiting for Management Group structure consistency" -FunctionName "BeforeAll"

        $script:mgmt = Get-AzManagementGroup
        $script:testManagementGroup = ($script:mgmt | Where-Object Name -eq "$($script:functionalTestDeploy.parameters.managementGroupId.value)")

        if ($script:testManagementGroup -ne $null) {
            $script:mgmtRun = "Done"
        }
        else {
            Start-Sleep -Seconds 60
            $script:timeOutMinutes--
        }
        if ($script:timeOutMinutes -le 0) {
            break
        }
    }

    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed"
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
    throw
}