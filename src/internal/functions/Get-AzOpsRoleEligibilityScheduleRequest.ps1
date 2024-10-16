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

        $roleEligibilitySchedules = Invoke-AzOpsScriptBlock -ArgumentList @($ScopeObject) -ScriptBlock {
            Get-AzRoleEligibilitySchedule -Scope $ScopeObject.Scope -WarningAction SilentlyContinue -ErrorAction Stop | Where-Object { $_.Scope -eq $ScopeObject.Scope }
        } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop

        if ($roleEligibilitySchedules) {
            $roleEligibilityScheduleRequests = Invoke-AzOpsScriptBlock -ArgumentList @($ScopeObject) -ScriptBlock {
                Get-AzRoleEligibilityScheduleRequest -Scope $ScopeObject.Scope -ErrorAction Stop 
            } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop
        } 
        
        if (-not $roleEligibilityScheduleRequests) {
            return
        }
        
        foreach ($roleEligibilitySchedule in $roleEligibilitySchedules) {
            # Process roleEligibilitySchedule together with RoleEligibilityScheduleRequest
            $roleEligibilityScheduleRequest = $roleEligibilityScheduleRequests.Where{ $_.TargetRoleEligibilityScheduleId -eq $roleEligibilitySchedule.Id }
            if ($roleEligibilityScheduleRequest -and $roleEligibilityScheduleRequest.Count -eq 1) {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Assignment' -LogStringValues $roleEligibilitySchedule.Name -Target $ScopeObject
                # Construct AzOpsRoleEligibilityScheduleRequest by combining information from roleEligibilitySchedule and roleEligibilityScheduleRequest
                [AzOpsRoleEligibilityScheduleRequest]::new($roleEligibilitySchedule, $roleEligibilityScheduleRequest)
            }
        }
    }
}