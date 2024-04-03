function New-AzOpsTestsDeploymentHelper {

    <#
        .SYNOPSIS
            Assists with deployments towards Azure to prime an environment before AzOps tests are called.
        .DESCRIPTION
            The functions’ purpose is to diminish code duplication in the functional tests deploy.ps1 files used by each resource type.
        .PARAMETER RuntimePath
            Path to functional test location on filesystem. This is used to derive the calling resource provider and resources type.
        .PARAMETER Scope
            Declare what scope the function should deploy towards.
            Example 'ResourceGroup','Subscription' or 'Tenant'.
        .PARAMETER Location
            Optional Location of deployment job.
        .PARAMETER DeployTemplateFileName
            Deployment template filename.
        .PARAMETER DeployTemplateParameterFileName
            Deployment templateparameter filename.
        .EXAMPLE
            > New-AzOpsTestsDeploymentHelper -RuntimePath $script:runtimePath -Scope $scope -DeployTemplateFileName $deployTemplate -DeployTemplateParameterFileName $deployTemplateParameter
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $RuntimePath,
        [Parameter(Mandatory = $false)]
        [ValidateSet('ResourceGroup','Subscription','Tenant')]
        [string]
        $Scope = 'ResourceGroup',
        [Parameter(Mandatory = $false)]
        [string]
        $Location = (Get-PSFConfigValue -FullName 'AzOps.Core.DefaultDeploymentRegion'),
        [Parameter(Mandatory = $true)]
        [string]
        $DeployTemplateFileName,
        [Parameter(Mandatory = $false)]
        [string]
        $DeployTemplateParameterFileName
    )

    process {
        if (-not $global:testroot) {
            Write-PSFMessage -Level Critical -Message "Missing global:testroot"
            throw
        }
        if (Test-Path $RuntimePath) {
            $script:resourceProvider = (Resolve-Path "$RuntimePath/..").Path.Split('/')[-2]
            $script:resourceType = (Resolve-Path "$RuntimePath/..").Path.Split('/')[-1]
        }
        else {
            Write-PSFMessage -Level Critical -Message "Test of path $RuntimePath failed"
            throw
        }
        if ($DeployTemplateFileName) {
            $script:templateFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$DeployTemplateFileName"
            if (-not (Test-Path $script:templateFile)) {
                Write-PSFMessage -Level Critical -Message "Test of path $script:templateFile failed"
                throw
            }
        }
        if ($DeployTemplateParameterFileName) {
            $script:templateParametersFile = Join-Path -Path $global:testroot -ChildPath "functional/$script:resourceProvider/$script:resourceType/deploy/$DeployTemplateParameterFileName"
            if (-not (Test-Path $script:templateParametersFile)) {
                Write-PSFMessage -Level Critical -Message "Test of path $script:templateParametersFile failed"
                throw
            }
        }
        switch ($PSBoundParameters['Scope']) {
            'ResourceGroup' {
                try {
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting at $Scope scope."
                    $script:resourceGroupName = $script:resourceType + "-" + (Get-Date -UFormat "%Y%m%d%R" | ForEach-Object {$_ -replace ":", ""}) + "-azopsrg"
                    $script:scope = New-AzResourceGroup -Name $script:resourceGroupName -Location $Location -Confirm:$false -Force
                    if ($script:templateParametersFile) {
                        $script:functionalTestDeploy = New-AzResourceGroupDeployment -Name ($script:resourceType + 'testdeploy') -ResourceGroupName $script:resourceGroupName -TemplateFile $script:templateFile -TemplateParameterFile $script:templateParametersFile -Confirm:$false -Force
                    }
                    else {
                        $script:functionalTestDeploy = New-AzResourceGroupDeployment -Name ($script:resourceType + 'testdeploy') -ResourceGroupName $script:resourceGroupName -TemplateFile $script:templateFile -Confirm:$false -Force
                    }
                    $script:return = [PSCustomObject]@{
                        functionalTestDeploy    = $script:functionalTestDeploy
                        functionalTestDeployJob = (($script:resourceType) + 'FunctionalTestDeploy')
                    }
                    return $script:return
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed at $Scope scope."
                }
                catch {
                    Write-PSFMessage -Level Critical -Message "Deployment of $script:resourceType starting at $Scope scope failed." -Exception $_.Exception
                    throw
                }
            }
            'Subscription' {
                try {
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting at $Scope scope."
                    if ($script:templateParametersFile) {
                        $script:functionalTestDeploy = New-AzDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -TemplateParameterFile $script:templateParametersFile -Location $Location -Confirm:$false
                    }
                    else {
                        $script:functionalTestDeploy = New-AzDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -Location $Location -Confirm:$false
                    }
                    $script:return = [PSCustomObject]@{
                        functionalTestDeploy    = $script:functionalTestDeploy
                        functionalTestDeployJob = (($script:resourceType) + 'FunctionalTestDeploy')
                    }
                    return $script:return
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed at $Scope scope."
                }
                catch {
                    Write-PSFMessage -Level Critical -Message "Deployment of $script:resourceType starting at $Scope scope failed." -Exception $_.Exception
                    throw
                }
            }
            'Tenant' {
                try {
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType starting at $Scope scope."
                    if ($script:templateParametersFile) {
                        $script:functionalTestDeploy = New-AzTenantDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -TemplateParameterFile $script:templateParametersFile -Location $Location
                    }
                    else {
                        $script:functionalTestDeploy = New-AzTenantDeployment -Name ($script:resourceType + 'testdeploy') -TemplateFile $script:templateFile -Location $Location
                    }
                    $script:return = [PSCustomObject]@{
                        functionalTestDeploy    = $script:functionalTestDeploy
                        functionalTestDeployJob = (($script:resourceType) + 'FunctionalTestDeploy')
                    }
                    return $script:return
                    Write-PSFMessage -Level Verbose -Message "Deployment of $script:resourceType completed at $Scope scope."
                }
                catch {
                    Write-PSFMessage -Level Critical -Message "Deployment of $script:resourceType starting at $Scope scope failed." -Exception $_.Exception
                    throw
                }
            }
        }
    }
}