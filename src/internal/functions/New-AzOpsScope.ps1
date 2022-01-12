function New-AzOpsScope {

    <#
        .SYNOPSIS
            Returns an AzOpsScope for a path or for a scope
        .DESCRIPTION
            Returns an AzOpsScope for a path or for a scope
        .PARAMETER Scope
            The scope for which to return a scope object.
        .PARAMETER Path
            The path from which to build a scope.
        .PARAMETER StatePath
            The root path to where the entire state is being built in.
        .PARAMETER ExtendedChildResource
            The ExtendedChildResource contains details of the child resource.
        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
        .EXAMPLE
            > New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"
            Return AzOpsScope for a root Management Group scope scope in Azure:
            scope                      : /providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560
            type                       : managementGroups
            name                       : 3fc1081d-6105-4e19-b60c-1ec1252cf560
            statepath                  : C:\git\cet-northstar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\.AzState\Microsoft.Management_managementGroups-3fc1081d-6105-4e19-b60c-1ec1252cf560.parameters.json
            managementgroup            : 3fc1081d-6105-4e19-b60c-1ec1252cf560
            managementgroupDisplayName : 3fc1081d-6105-4e19-b60c-1ec1252cf560
            subscription               :
            subscriptionDisplayName    :
            resourcegroup              :
            resourceprovider           :
            resource                   :
        .EXAMPLE
            > New-AzOpsScope -path  "C:\Users\jodahlbo\git\CET-NorthStar\azops\Tenant Root Group\Non-Production Subscriptions\Dalle MSDN MVP\365lab-dcs"
            Return AzOpsScope for a filepath
        .INPUTS
            Scope
        .INPUTS
            Path
        .OUTPUTS
            [AzOpsScope]
    #>

    #[OutputType([AzOpsScope])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ParameterSetName = "scope")]
        [string]
        [ValidateScript( { $null -ne $script:AzOpsAzManagementGroup -or $script:AzOpsSubscription })]
        $Scope,

        [Parameter(ParameterSetName = "pathfile", ValueFromPipeline = $true)]
        [string]
        $Path,
        
        [hashtable]
        $ExtendedChildResource,

        [string]
        $StatePath = (Get-PSFConfigValue -FullName 'AzOps.Core.State')
    )
    process {
        Write-PSFMessage -Level Debug -String 'New-AzOpsScope.Starting'

        switch ($PSCmdlet.ParameterSetName) {
            scope {
                if (($ExtendedChildResource) -and (-not(Get-PSFConfigValue -FullName AzOps.Core.SkipExtendedChildResourcesDiscovery))) {
                    Invoke-PSFProtectedCommand -ActionString 'New-AzOpsScope.Creating.FromParentScope' -ActionStringValues $Scope -Target $Scope -ScriptBlock {
                        [AzOpsScope]::new($Scope, $ExtendedChildResource, $StatePath)
                    } -EnableException $true -PSCmdlet $PSCmdlet
                }
                else {
                    Invoke-PSFProtectedCommand -ActionString 'New-AzOpsScope.Creating.FromScope' -ActionStringValues $Scope -Target $Scope -ScriptBlock {
                        [AzOpsScope]::new($Scope, $StatePath)
                    } -EnableException $true -PSCmdlet $PSCmdlet
                }
            }
            pathfile {
                if (-not (Test-Path $Path)) {
                    Stop-PSFFunction -String 'New-AzOpsScope.Path.NotFound' -StringValues $Path -EnableException $true -Cmdlet $PSCmdlet
                }
                $Path = Resolve-PSFPath -Path $Path -SingleItem -Provider FileSystem
                $StatePathValidator = Resolve-PSFPath -Path $StatePath -SingleItem -Provider FileSystem
                if (-not $Path.StartsWith($StatePathValidator)) {
                    Stop-PSFFunction -String 'New-AzOpsScope.Path.InvalidRoot' -StringValues $Path, $StatePath -EnableException $true -Cmdlet $PSCmdlet
                }
                Invoke-PSFProtectedCommand -ActionString 'New-AzOpsScope.Creating.FromFile' -Target $Path -ScriptBlock {
                    [AzOpsScope]::new($(Get-Item -Path $Path -Force), $StatePath)
                } -EnableException $true -PSCmdlet $PSCmdlet
            }
        }
    }
}
