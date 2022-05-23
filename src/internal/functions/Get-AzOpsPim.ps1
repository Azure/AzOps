function Get-AzOpsPim {
    <#
        .SYNOPSIS
            Get Privileged Identity Management objects from provided scope
        .PARAMETER ScopeObject
            ScopeObject
        .PARAMETER StatePath
            StatePath
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        # Process RoleEligibilitySchedule
        Write-PSFMessage -Level Verbose -String 'Get-AzOpsResourceDefinition.Processing.Detail' -StringValues 'RoleEligibilitySchedule', $scopeObject.Scope
        $roleEligibilityScheduleRequest = Get-AzOpsRoleEligibilityScheduleRequest -ScopeObject $ScopeObject
        if ($roleEligibilityScheduleRequest) {
            $roleEligibilityScheduleRequest | ConvertTo-AzOpsState -StatePath $StatePath
        }
    }
}