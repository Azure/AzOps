{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "_generator": {
            "name": "AzOps"
        }
    },
    "parameters": {
        "scope": {
            "type": "string",
            "defaultValue": .Properties.scope
        },
        "location": {
            "type": "string",
            "defaultValue": .Location
        },
        "enforcementMode": {
            "type": "string",
            "defaultValue": .Properties.enforcementMode
        },
        "policyparameters": {
            "type": "object",
            "defaultValue": .Properties.parameters
        },
        "identity": {
            "type": "object",
            "defaultValue": (if (.Identity.Type == "SystemAssigned" ) then {type: "SystemAssigned",PrincipalId:.Identity.PrincipalId,TenantId:.Identity.TenantId} else {type: "UserAssigned", UserAssignedIdentities : { (.Identity.UserAssignedIdentities | to_entries[] | .key) : {} } } end)
        }
    },
    "variables": {},
    "resources": [
        {
            "type": .Type,
            "name": .Name,
            "apiVersion": "2022-06-01",
            "location": "[parameters('location')]",
            "identity": "[parameters('identity')]",
            "properties": {
                "description": .Properties.Description,
                "displayName":  .Properties.displayName,
                "enforcementMode": "[parameters('enforcementMode')]",
                "policyDefinitionId": .Properties.policyDefinitionId,
                "scope": .Properties.scope,
                "parameters": "[parameters('policyparameters')]"
            }
        }
    ],
    "outputs": {}
} | del(.ResourceId, .resourceGroup, .subscriptionId, .properties.metadata.createdOn, .properties.metadata.updatedOn, .properties.metadata.createdBy, .properties.metadata.createdBy, .properties.metadata.updatedBy, .properties.metadata.assignedBy )
