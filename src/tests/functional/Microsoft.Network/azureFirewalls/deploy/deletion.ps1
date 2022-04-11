$script:resourceProvider = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-2]
$script:resourceType = (Resolve-Path "$PSScriptRoot/..").Path.Split('/')[-1]

$script:resourceGroupName = $script:resourceType + "-rg"

try {
    Write-PSFMessage -Level Verbose -Message "Deletion of $script:resourceType starting"
    $script:scope = Remove-AzResourceGroup -Name $script:resourceGroupName -Confirm:$false -Force
    Write-PSFMessage -Level Verbose -Message "Deletion of $script:resourceType completed"
}
catch {
    Write-PSFMessage -Level Critical -Message "Deletion of $script:resourceType failed" -Exception $_.Exception
    throw
}