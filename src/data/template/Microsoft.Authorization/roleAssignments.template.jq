{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
      "name": {
          "type": "string",
          "defaultValue": .name
      },
      "principalId": {
          "type": "string",
          "defaultValue": .properties.principalId
      },
      "principalType": {
          "type": "string",
          "defaultValue": .properties.principalType
      },
      "roleDefinitionId": {
          "type": "string",
          "defaultValue": .properties.roleDefinitionId
      },
      "scope": {
          "type": "string",
          "defaultValue": .properties.scope
      }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Authorization/roleAssignments",
      "name": "[parameters('name')]",
      "apiVersion": "2022-04-01",
      "properties": {
        "principalId": "[parameters('principalId')]",
        "principalType": "[parameters('principalType')]",
        "roleDefinitionId": "[parameters('roleDefinitionId')]",
        "scope": "[parameters('scope')]"
      }
    }
  ],
  "outputs": {}
}