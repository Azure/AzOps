function Remove-AzOpsDeployment {
    <#
        .SYNOPSIS
            Delete policyAssignments, policyExemptions and roleAssignments from azure.
        .DESCRIPTION
            Delete policyAssignments, policyExemptions and roleAssignments from azure.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER StatePath
            The root folder under which to find the resource json.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > $AzOpsRemovalList | Select-Object $uniqueProperties -Unique | Remove-AzOpsDeployment
            Remove all unique deployments provided from $AzOpsRemovalList
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        $TemplateFilePath = (Get-PSFConfigValue -FullName 'AzOps.Core.MainTemplate'),

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )

    process {
        #Deployment Name
        $fileItem = Get-Item -Path $TemplateFilePath
        $removeJobName = $fileItem.BaseName -replace '\.json$' -replace ' ', '_'
        $removeJobName = "AzOps-RemoveResource-$removeJobName"
        Write-PSFMessage -Level Important -String 'Remove-AzOpsDeployment.Processing' -StringValues $removeJobName, $TemplateFilePath -Target $TemplateFilePath
        #region Parse Content
        $templateContent = Get-Content $TemplateFilePath | ConvertFrom-Json -AsHashtable
        #endregion
        #region Validate it is AzOpsgenerated template
        if ($templateContent.metadata._generator.name -eq "AzOps") {
            Write-PSFMessage -Level Verbose -Message 'Remove-AzOpsDeployment.Metadata.Success' -StringValues $TemplateFilePath -Target $TemplateFilePath
        }
        else {
            Write-PSFMessage -Level Error -Message 'Remove-AzOpsDeployment.Metadata.Failed' -StringValues $TemplateFilePath -Target $TemplateFilePath
            return
        }
        #endregion Validate it is AzOpsgenerated template
        #region Resolve Scope
        try {
            $scopeObject = New-AzOpsScope -Path $TemplateFilePath -StatePath $StatePath -ErrorAction Stop -WhatIf:$false
        }
        catch {
            Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.Scope.Failed' -Target $TemplateFilePath -StringValues $TemplateFilePath -ErrorRecord $_
            return
        }
        if (-not $scopeObject) {
            Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.Scope.Empty' -Target $TemplateFilePath -StringValues $TemplateFilePath
            return
        }
        #endregion Resolve Scope

        #region SetContext
        Set-AzOpsContext -ScopeObject $scopeObject
        #endregion SetContext

        #region remove supported resources
        if ($scopeObject.Resource -in 'policyAssignments', 'policyExemptions', 'roleAssignments') {
            switch ($scopeObject.Resource) {
                # Check resource existance through optimal path
                'policyAssignments' {
                    $resourceToDelete = Get-AzPolicyAssignment -Id $scopeObject.scope -ErrorAction SilentlyContinue
                }
                'policyExemptions' {
                    $resourceToDelete = Get-AzPolicyExemption -Id $scopeObject.scope -ErrorAction SilentlyContinue
                }
                'roleAssignments' {
                    $resourceToDelete = Invoke-AzRestMethod -Path "$($scopeObject.scope)?api-version=2022-01-01-preview" | Where-Object { $_.StatusCode -eq 200 }
                }
            }
            if (-not $resourceToDelete) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.ResourceNotFound' -StringValues $scopeObject.Resource, $scopeObject.Scope -Target $scopeObject
                $results = '{0}: What if Operation Failed: Deletion of target resource {1}. Resource could not be found' -f $removeJobName, $scopeObject.scope
                Set-AzOpsWhatIfOutput -StatePath $scopeObject.StatePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            $results = '{0}: What if Successful: Performing the operation: Deletion of target resource {1}.' -f $removeJobName, $scopeObject.scope
            Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
            Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
            Set-AzOpsWhatIfOutput -StatePath $scopeObject.StatePath -Results $results -RemoveAzOpsFlag $true

            if ($PSCmdlet.ShouldProcess("Remove $($scopeObject.Scope)?")) {
                $null = Remove-AzResource -ResourceId $scopeObject.Scope -Force
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
    }
}
