{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "virtualNetwork": {
       "type": "object",
       "defaultValue": .properties.virtualNetwork
    },
    "resourceId": {
       "type": "string",
       "defaultValue": .ResourceId
    }
  },
  "variables": {
    "name": "[concat(split(parameters('resourceId'),'/')[8],'/',split(parameters('resourceId'),'/')[10])]"
  },
  "resources": [
    {
      "type": "Microsoft.Network/privateDnsZones/virtualnetworklinks",
      "name": "[variables('name')]",
      "apiVersion": "2020-06-01",
      "location": .location,
      "properties": {
        "registrationEnabled": false,
        "virtualNetwork": "[parameters('virtualNetwork')]"
      }
    }
  ],
  "outputs": {}
}