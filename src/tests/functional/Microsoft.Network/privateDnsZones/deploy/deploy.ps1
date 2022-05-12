$script:runtimePath = $PSScriptRoot
$script:deployTemplate = "deploy.json"
$script:deployTemplateParameter = "deploy.parameters.json"
$script:scope = "ResourceGroup"

try {
    New-AzOpsTestsDeploymentHelper -RuntimePath $script:runtimePath -Scope $script:scope -DeployTemplateFileName $script:deployTemplate -DeployTemplateParameterFileName $script:deployTemplateParameter
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
    throw
}
