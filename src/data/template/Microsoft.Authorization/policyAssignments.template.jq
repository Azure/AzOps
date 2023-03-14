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
            "defaultValue": .properties.scope
        },
        "location": {
            "type": "string",
            "defaultValue": .location
        },
        "enforcementMode": {
            "type": "string",
            "defaultValue": .properties.enforcementMode
        },
        "policyparameters": {
            "type": "object",
            "defaultValue": .properties.parameters
        },
        "identity": {
            "type": "object",
            "defaultValue": ( if (.identity.type == "UserAssigned") then { type: "UserAssigned", userAssignedIdentities : { (.identity.userAssignedIdentities | to_entries[] | .key) : {} } } else { type:"SystemAssigned" , PrincipalId:.identity.principalId, TenantId:.identity.tenantId } end)
        }
    },
    "variables": {},
    "resources": [
        {
            "type": .Type,
            "name": .name,
            "apiVersion": "2022-06-01",
            "location": "[parameters('location')]",
            "identity": "[parameters('identity')]",
            "properties": {
                "description": .properties.description,
                "displayName":  .properties.displayName,
                "enforcementMode": "[parameters('enforcementMode')]",
                "policyDefinitionId": .properties.policyDefinitionId,
                "scope": "[parameters('scope')]",
                "parameters": "[parameters('policyparameters')]"
            }
        }
    ],
    "outputs": {}
}