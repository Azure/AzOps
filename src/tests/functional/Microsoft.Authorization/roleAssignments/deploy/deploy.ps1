$script:runtimePath = $PSScriptRoot
$script:deployTemplate = "deploy.bicep"
$script:scope = "Subscription"

try {
    New-AzOpsTestsDeploymentHelper -RuntimePath $script:runtimePath -Scope $script:scope -DeployTemplateFileName $script:deployTemplate
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
    throw
}