class AzOpsRoleDefinition {
    [string]$ResourceType
    [string]$Name
    [string]$Id
    [hashtable]$Properties
    
    AzOpsRoleDefinition($Properties) {
        $this.Id = $Properties.AssignableScopes[0] + '/providers/Microsoft.Authorization/roleDefinitions/' + $Properties.Id
        $this.Name = $Properties.Id
        $this.Properties = [ordered]@{
            AssignableScopes = @($Properties.AssignableScopes)
            Description	     = $Properties.Description
            Permissions	     = @(
                [ordered]@{
                    Actions = @($Properties.Actions)
                    DataActions = @($Properties.DataActions)
                    NotActions = @($Properties.NotActions)
                    NotDataActions = @($Properties.NotDataActions)
                }
            )
            RoleName		 = $Properties.Name
        }
        $this.ResourceType = "Microsoft.Authorization/roleDefinitions"
    }
}