class AzOpsRoleDefinition {
    [string]$ResourceType
    [string]$Name
    [string]$Id
    [hashtable]$Properties
    AzOpsRoleDefinition($Properties) {
        # Removing the Trailing slash to ensure that '/' is not appended twice when adding '/providers/xxx'.
        # Example: '/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/' is a valid assignment scope.
        $this.Id = '/' + $Properties.AssignableScopes[0].Trim('/') + '/providers/Microsoft.Authorization/roleDefinitions/' + $Properties.Id
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