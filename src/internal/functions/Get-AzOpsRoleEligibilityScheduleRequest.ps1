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
        try {
            $parameters = @{
                Scope = $ScopeObject.Scope
            }
            $roleEligibilitySchedules = Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                Get-AzRoleEligibilitySchedule @parameters -WarningAction SilentlyContinue -ErrorAction Stop | Where-Object { $_.Scope -eq $parameters.Scope }
            } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Processing.Failed' -LogStringValues $_
            return
        }
        if ($roleEligibilitySchedules) {
            foreach ($roleEligibilitySchedule in $roleEligibilitySchedules) {
                # Process roleEligibilitySchedule together with RoleEligibilityScheduleRequest
                $parameters = @{
                    Scope = $ScopeObject.Scope
                    Name = $roleEligibilitySchedule.Name
                }
                $roleEligibilityScheduleRequest = $null
                $roleEligibilityScheduleRequest = Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                    Get-AzRoleEligibilityScheduleRequest @parameters -ErrorAction SilentlyContinue
                } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction SilentlyContinue
                if ($roleEligibilityScheduleRequest) {
                    Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Assignment' -LogStringValues $roleEligibilitySchedule.Name -Target $ScopeObject
                    # Construct AzOpsRoleEligibilityScheduleRequest by combining information from roleEligibilitySchedule and roleEligibilityScheduleRequest
                    [AzOpsRoleEligibilityScheduleRequest]::new($roleEligibilitySchedule, $roleEligibilityScheduleRequest)
                }
                else {
                    Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsRoleEligibilityScheduleRequest.Processing.NotFound' -LogStringValues $ScopeObject.Scope, $roleEligibilitySchedule.Name -Target $ScopeObject
                    # Construct AzOpsRoleEligibilityScheduleRequest from roleEligibilitySchedule since no AzRoleEligibilityScheduleRequest was found
                    [AzOpsRoleEligibilityScheduleRequest]::new($roleEligibilitySchedule)
                }
            }
        }
    }
}