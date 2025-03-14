﻿class AzOpsRoleEligibilityScheduleRequest {
    [string]$ResourceType
    [string]$Name
    [string]$Id
    [hashtable]$Properties

    AzOpsRoleEligibilityScheduleRequest($roleEligibilitySchedule, $roleEligibilityScheduleRequest) {
        $this.Properties = [ordered]@{
            Condition = $roleEligibilitySchedule.Condition
            ConditionVersion = $roleEligibilitySchedule.ConditionVersion
            PrincipalId = $roleEligibilitySchedule.PrincipalId
            RoleDefinitionId = $roleEligibilitySchedule.RoleDefinitionId
            RequestType = $roleEligibilityScheduleRequest.RequestType.ToString()
            ScheduleInfo = [ordered]@{
                Expiration = [ordered]@{
                    EndDateTime = $roleEligibilitySchedule.EndDateTime
                    Duration = $roleEligibilitySchedule.ExpirationDuration
                    ExpirationType = if ($roleEligibilitySchedule.ExpirationType) {$roleEligibilitySchedule.ExpirationType.ToString()}
                }
                StartDateTime  = $roleEligibilitySchedule.StartDateTime
            }
        }
        $this.Id = $roleEligibilitySchedule.RequestId
        $this.Name = $roleEligibilitySchedule.Name
        $this.ResourceType = $roleEligibilityScheduleRequest.Type
    }

    AzOpsRoleEligibilityScheduleRequest($roleEligibilitySchedule) {
        $this.Properties = [ordered]@{
            Condition = $roleEligibilitySchedule.Condition
            ConditionVersion = $roleEligibilitySchedule.ConditionVersion
            PrincipalId = $roleEligibilitySchedule.PrincipalId
            RoleDefinitionId = $roleEligibilitySchedule.RoleDefinitionId
            RequestType = "AdminAssign"
            ScheduleInfo = [ordered]@{
                Expiration = [ordered]@{
                    EndDateTime = $roleEligibilitySchedule.EndDateTime
                    Duration = $roleEligibilitySchedule.ExpirationDuration
                    ExpirationType = if ($roleEligibilitySchedule.ExpirationType) {$roleEligibilitySchedule.ExpirationType.ToString()}
                }
                StartDateTime  = $roleEligibilitySchedule.StartDateTime
            }
        }
        $this.Id = $roleEligibilitySchedule.RequestId
        $this.Name = $roleEligibilitySchedule.Name
        $this.ResourceType = "Microsoft.Authorization/roleEligibilityScheduleRequests"
    }
}