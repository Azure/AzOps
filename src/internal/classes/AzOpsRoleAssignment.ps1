class AzOpsRoleAssignment {
    [string]$ResourceType
    [string]$Name
    [string]$Id
    [hashtable]$Properties
    
    AzOpsRoleAssignment($Properties) {
        $this.Properties = [ordered]@{
            DisplayName = $Properties.DisplayName
            PrincipalId = $Properties.ObjectId
            RoleDefinitionName = $Properties.RoleDefinitionName
            ObjectType  = $Properties.ObjectType
            RoleDefinitionId = '/providers/Microsoft.Authorization/RoleDefinitions/{0}' -f $Properties.RoleDefinitionId
        }
        $this.Id = $Properties.RoleAssignmentId
        $this.Name = ($Properties.RoleAssignmentId -split "/")[-1]
        $this.ResourceType = "Microsoft.Authorization/roleAssignments"
    }
}