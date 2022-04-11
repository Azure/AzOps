$script:resourceProvider = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-2]
$script:resourceType = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-1]
$script:functionalTestDeploy = Get-Variable -Name (($script:resourceType) + 'FunctionalTestDeploy') -Scope Global

try {
    Write-PSFMessage -Level Verbose -Message "Deletion of $script:resourceType starting"
    $script:functionalTestDeploy.Value | Remove-AzDeployment -Confirm:$false
    Write-PSFMessage -Level Verbose -Message "Deletion of $script:resourceType completed"
}
catch {
    Write-PSFMessage -Level Critical -Message "Deletion of $script:resourceType failed" -Exception $_.Exception
    throw
}