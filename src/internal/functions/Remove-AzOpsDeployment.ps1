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

        #GetContext
        $contextObjectId = (Get-AzOpsCurrentPrincipal).id

        #region policyAssignments
        if ($scopeObject.Resource -eq "policyAssignments") {
            $policyAssignment = Get-AzPolicyAssignment -Id $scopeObject.scope -ErrorAction Continue -ErrorVariable resultsError
            if (($resultsError -ne $null) -or (-not $policyAssignment)) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.RemovePolicyAssignment.NoPolicyAssignmentFound' -StringValues $scopeObject.Scope, $resultsError -Target $scopeObject
                $results = '{0}: What if Operation Failed: Performing the operation "Deleting the policy assignment..." on target {1}.' -f $removeJobName, $scopeObject.scope
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            else {
                $results = '{0}: What if Successful: Performing the operation "Deleting the policy assignment..." on target {1}.' -f $removeJobName, $scopeObject.scope
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            #remove resource
            if ($PSCmdlet.ShouldProcess("RemovePolicyAssignment?")) {
                Remove-AzPolicyAssignment -Id $scopeObject.scope -ErrorAction Stop
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion policyAssignments
        #region policyExemptions
        if ($scopeObject.Resource -eq "policyExemptions") {
            $policyExemption = Get-AzPolicyExemption -Id $scopeObject.scope -ErrorAction Continue -ErrorVariable resultsError
            if (($resultsError -ne $null) -or (-not $policyExemption)) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.RemovePolicyExemption.NoPolicyExemptionFound' -StringValues $scopeObject.Scope, $resultsError -Target $scopeObject
                $results = '{0}: What if Operation Failed: Performing the operation "Deleting the policy exemption..." on target {1}.' -f $removeJobName, $scopeObject.scope
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            else {
                $results = '{0}: What if Successful: Performing the operation "Deleting the policy exemption..." on target {1}.' -f $removeJobName, $scopeObject.scope
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            #remove resource
            if ($PSCmdlet.ShouldProcess("RemovePolicyExemption?")) {
                $null = Remove-AzPolicyExemption -Id $scopeObject.scope -Force -ErrorAction Stop
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion policyExemptions
        #region roleAssignments
        if ($scopeObject.Resource -eq "roleAssignments") {
            $scopeOfRoleAssignment = $scopeObject.scope
            $scopeOfRoleAssignment = $scopeOfRoleAssignment.Substring(0, $scopeOfRoleAssignment.LastIndexOf('/providers'))
            $roleAssignment = Get-AzRoleAssignment -ObjectId $templateContent.resources[0].properties.PrincipalId -RoleDefinitionName $templateContent.resources[0].properties.RoleDefinitionName -scope $scopeOfRoleAssignment -ErrorAction Continue -ErrorVariable roleAssignmentError -WarningAction SilentlyContinue
            if (($roleAssignmentError -ne $null) -or (-not $roleAssignment)) {
                Write-PSFMessage -Level Warning -String 'Remove-AzOpsDeployment.RemoveRoleAssignment.NoRoleAssignmentFound' -StringValues $scopeObject.Scope, $resultsError -Target $scopeObject
                $results = '{0}: What if Failed: Performing the operation Removing role assignment for AD object {1} on scope {2} with role definition {3} on target {1}' -f $removeJobName, $templateContent.resources[0].properties.PrincipalId, $roleAssignment.Scope, $templateContent.resources[0].properties.RoleDefinitionName
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
                return
            }
            else {
                $results = '{0}: What if Successful: Performing the operation Removing role assignment for AD object {1} on scope {2} with role definition {3} on target {1}' -f $removeJobName, $templateContent.resources[0].properties.PrincipalId, $roleAssignment.Scope, $templateContent.resources[0].properties.RoleDefinitionName
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfResults' -StringValues $results -Target $scopeObject
                Write-PSFMessage -Level Verbose -String 'Set-AzOpsWhatIfOutput.WhatIfFile' -Target $scopeObject
                Set-AzOpsWhatIfOutput -TemplatePath $TemplateFilePath -Results $results -RemoveAzOpsFlag $true
            }
            #Remove of Resource
            if ($PSCmdlet.ShouldProcess("RemoveRoleAssignment?")) {
                Remove-AzRoleAssignment -ObjectId $templateContent.resources[0].properties.PrincipalId -RoleDefinitionName $templateContent.resources[0].properties.RoleDefinitionName -Scope $roleAssignment.Scope -ErrorAction Stop
            }
            else {
                Write-PSFMessage -Level Verbose -String 'Remove-AzOpsDeployment.SkipDueToWhatIf'
            }
        }
        #endregion roleassignments
    }
}