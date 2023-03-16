{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
      "containedResources": {
          "type": "array",
          "defaultValue": .properties.containedResources
      },
      "workspaceResourceId": {
          "type": "string",
          "defaultValue": .properties.workspaceResourceId
      },
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.OperationsManagement/solutions",
      "name": .name,
      "apiVersion": "2015-11-01-preview",
      "location": .location,
      "properties": {
        "containedResources": "[parameters('containedResources')]",
        "workbookTemplates": [],
        "workspaceResourceId": "[parameters('workspaceResourceId')]"
      }
    }
  ],
  "outputs": {}
}
