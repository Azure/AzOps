$script:runtimePath = $PSScriptRoot
$script:deployTemplate = "deploy.bicep"
$script:scope = "Tenant"

try {
    New-AzOpsTestsDeploymentHelper -RuntimePath $script:runtimePath -Scope $script:scope -DeployTemplateFileName $script:deployTemplate

    $script:timeOutMinutes = 30
    $script:mgmtRun = "Run"

    While ($script:mgmtRun -eq "Run") {
        Write-PSFMessage -Level Verbose -Message "Waiting for Management Group structure consistency" -FunctionName "BeforeAll"

        $script:mgmt = Get-AzManagementGroup
        $script:testManagementGroup = ($script:mgmt | Where-Object Name -eq "AzOpsMGMTID")

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
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
    throw
}