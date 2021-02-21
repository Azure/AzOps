function Save-AzOpsManagementGroupChildren {

    <#
        .SYNOPSIS
            Recursively build/change Management Group hierarchy in file system from provided scope.
        .DESCRIPTION
            Recursively build/change Management Group hierarchy in file system from provided scope.
        .PARAMETER Scope
            Scope to discover - assumes [AzOpsScope] object
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .EXAMPLE
            > Save-AzOpsManagementGroupChildren -Scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
            Discover Management Group hierarchy from scope
        .INPUTS
            AzOpsScope
        .OUTPUTS
            Management Group hierarchy in file system
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType()]
    param (
        [Parameter(Mandatory = $true)]
        $Scope,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.General.State')
    )

    process {
        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Starting'
        Invoke-PSFProtectedCommand -ActionString 'Save-AzOpsManagementGroupChildren.Creating.Scope' -Target $Scope -ScriptBlock {
            $scopeObject = New-AzOpsScope -Scope $Scope -StatePath $StatePath -ErrorAction SilentlyContinue -Confirm:$false
        } -EnableException $true -PSCmdlet $PSCmdlet
        if (-not $scopeObject) { return } # In case -WhatIf is used

        Write-PSFMessage -String 'Save-AzOpsManagementGroupChildren.Processing' -StringValues $scopeObject.Scope

        # Construct all file paths for scope
        $scopeStatepath = $scopeObject.StatePath
        $statepathFileName = [IO.Path]::GetFileName($scopeStatepath)
        $statepathDirectory = [IO.Path]::GetDirectoryName($scopeStatepath)
        $statepathScopeDirectory = [IO.Directory]::GetParent($statepathDirectory).ToString()
        $statepathScopeDirectoryParent = [IO.Directory]::GetParent($statepathScopeDirectory).ToString()

        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Data.StatePath' -StringValues $scopeStatepath
        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Data.FileName' -StringValues $statepathFileName
        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Data.Directory' -StringValues $statepathDirectory
        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Data.ScopeDirectory' -StringValues $statepathScopeDirectory
        Write-PSFMessage -Level Debug -String 'Save-AzOpsManagementGroupChildren.Data.ScopeDirectoryParent' -StringValues $statepathScopeDirectoryParent

        if (-not (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName)) {
            # If StatePathFilename do not exists inside AzOpsState, create one
            Write-PSFMessage -String 'Save-AzOpsManagementGroupChildren.New.File' -StringValues $statepathFileName
        }
        elseif ($statepathScopeDirectoryParent -ne (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName).Directory.Parent.Parent.FullName) {
            # File Exists but parent is not the same, looking for Parent (.AzState) of a Parent to determine
            $exisitingScopePath = (Get-ChildItem -Path $scopeStatepath -File -Recurse -Force | Where-Object Name -eq $statepathFileName).Directory.Parent.FullName
            Write-PSFMessage -String 'Save-AzOpsManagementGroupChildren.Moving.Source' -StringValues $exisitingScopePath
            Move-Item -Path $exisitingScopePath -Destination $statepathScopeDirectoryParent
            Write-PSFMessage -String 'Save-AzOpsManagementGroupChildren.Moving.Destination' -StringValues $statepathScopeDirectoryParent
        }

        switch ($scopeObject.Type) {
            managementGroups
            {
                ConvertTo-AzOpsState -Resource $script:AzOpsAzManagementGroup.Where{ $_.Name -eq $scopeObject.managementgroup } -ExportPath $scopeObject.statepath -StatePath $StatePath
                foreach ($child in $script:AzOpsAzManagementGroup.Where{ $_.Name -eq $scopeObject.managementgroup }.Children) {
                    Save-AzOpsManagementGroupChildren -Scope $child.Id -StatePath $StatePath
                }
            }
            subscriptions
            {
                ConvertTo-AzOpsState -Resource ($script:AzOpsAzManagementGroup.children | Where-Object Name -eq $scopeObject.name) -ExportPath $scopeObject.statepath -StatePath $StatePath
            }
        }
    }

}