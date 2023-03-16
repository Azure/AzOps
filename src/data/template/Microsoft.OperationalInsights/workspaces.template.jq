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
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.OperationalInsights/workspaces",
      "name": "[parameters('name')]",
      "apiVersion": "2022-10-01",
      "location": .location,
      "properties": {
        "retentionInDays": 30,
        "sku": {
          "name": "pergb2018"
        },
        "enableLogAccessUsingOnlyResourcePermissions": true
      }
    }
  ],
  "outputs": {}
}
