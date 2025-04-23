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
        [object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        # Process RoleEligibilitySchedule
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsResourceDefinition.Processing.Detail' -LogStringValues 'RoleEligibilitySchedule', $scopeObject.Scope
        $roleEligibilityScheduleRequest = Get-AzOpsRoleEligibilityScheduleRequest -ScopeObject $ScopeObject
        if ($roleEligibilityScheduleRequest) {
            $roleEligibilityScheduleRequest | ConvertTo-AzOpsState -StatePath $StatePath
        }
    }
}