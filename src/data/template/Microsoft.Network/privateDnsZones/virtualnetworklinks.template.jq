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
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/privateDnsZones/virtualnetworklinks",
      "name": .name,
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
