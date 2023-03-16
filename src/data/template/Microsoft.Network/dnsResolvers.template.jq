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
      "type": "Microsoft.Network/dnsResolvers",
      "name": .name,
      "apiVersion": "2022-07-01",
      "location": .location,
      "properties": {
        "virtualNetwork": "[parameters('virtualNetwork')]"
      }
    }
  ],
  "outputs": {}
}
