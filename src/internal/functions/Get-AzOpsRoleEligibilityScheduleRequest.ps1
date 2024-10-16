function Get-AzOpsRoleEligibilityScheduleRequest {

    <#
        .SYNOPSIS
            Discover all Privileged Identity Management RoleEligibilityScheduleRequest at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all Privileged Identity Management RoleEligibilityScheduleRequest at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve policy definitions for.
        .EXAMPLE
            > Get-AzOpsRoleEligibilityScheduleRequest -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all Privileged Identity Management RoleEligibilityScheduleRequest at Management Group scope
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        if ($ScopeObject.Type -notin 'resourceGroups', 'subscriptions', 'managementGroups') {
            return
        }

        # Process RoleEligibilitySchedule which is used to construct AzOpsRoleEligibilityScheduleRequest
        Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Processing' -LogStringValues $ScopeObject.Scope -Target $ScopeObject
        $roleEligibilitySchedules = Get-AzRoleEligibilitySchedule -Scope $ScopeObject.Scope -WarningAction SilentlyContinue | Where-Object {$_.Scope -eq $ScopeObject.Scope}
        if ($roleEligibilitySchedules) {
            foreach ($roleEligibilitySchedule in $roleEligibilitySchedules) {
                # Process roleEligibilitySchedule together with RoleEligibilityScheduleRequest
                $roleEligibilityScheduleRequest = Get-AzRoleEligibilityScheduleRequest -Scope $ScopeObject.Scope -Name $roleEligibilitySchedule.Name -ErrorAction SilentlyContinue
                if ($roleEligibilityScheduleRequest) {
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Assignment' -LogStringValues $roleEligibilitySchedule.Name -Target $ScopeObject
                    # Construct AzOpsRoleEligibilityScheduleRequest by combining information from roleEligibilitySchedule and roleEligibilityScheduleRequest
                    [AzOpsRoleEligibilityScheduleRequest]::new($roleEligibilitySchedule, $roleEligibilityScheduleRequest)
                else {
                    Write-AzOpsMessage -LogLevel Important -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Processing' -LogStringValues "No RoleEligibilityScheduleRequest found for RoleEligibilitySchedule in scope: $($ScopeObject.scope), creating template based on RoleEligibilitySchedule" -Target $ScopeObject
                    [AzOpsRoleEligibilityScheduleRequest]::new($roleEligibilitySchedule)
                }
            }
        }
    }
}