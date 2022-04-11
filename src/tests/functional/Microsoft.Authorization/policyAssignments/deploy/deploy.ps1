$script:location = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
$script:deployTemplate = "deploy.bicep"

$script:resourceProvider = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-2]
$script:resourceType = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-1]

$script:templateFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$script:deployTemplate"

try {
    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting"
    $script:functionalTestDeploy = New-AzSubscriptionDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -Location $script:location
    New-Variable -Name (($script:resourceType) + 'FunctionalTestDeploy') -Value $script:functionalTestDeploy -Scope Global -Force
    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed"
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment failed" -Exception $_.Exception
    throw
}