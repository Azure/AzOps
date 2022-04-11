$script:location = Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'
$script:deployTemplate = "deploy.json"
$script:deployTemplateParameters = "deploy.parameters.json"

$script:resourceProvider = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-2]
$script:resourceType = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-1]

$script:templateFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$script:deployTemplate"
$script:templateParametersFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$script:deployTemplateParameters"

$script:resourceGroupName = $script:resourceType + "-rg"

try {
    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting"
    $script:scope = New-AzResourceGroup -Name $script:resourceGroupName -Location $script:location -Confirm:$false -Force
    $script:functionalTestDeploy = New-AzResourceGroupDeployment -Name ($script:resourceType + 'testdeploy') -ResourceGroupName $script:resourceGroupName -TemplateFile $script:templateFile -TemplateParameterFile $script:templateParametersFile -Confirm:$false -Force
    New-Variable -Name (($script:resourceType) + 'FunctionalTestDeploy') -Value $script:functionalTestDeploy -Scope Global -Force
    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed"
}
catch {
    Write-PSFMessage -Level Critical -Message "Deployment of $script:resourceType failed" -Exception $_.Exception
    throw
}