{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "ipAddress": {
        "type": "string",
        "defaultValue": .properties.ipAddress
    },
    "ipConfiguration": {
        "type": "object",
        "defaultValue": .properties.ipConfiguration
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/publicIPAddresses",
      "name": .name,
      "sku": {
        "name": "Standard",
        "tier": "Regional"
      },
      "apiVersion": "2022-11-01",
      "location": .location,
      "properties": {
        "idleTimeoutInMinutes": 4,
        "ipAddress": "[parameters('ipAddress')]",
        "ipConfiguration":"[parameters('ipConfiguration')]",
        "ipTags": [],
        "publicIPAddressVersion": .properties.publicIPAddressVersion,
        "publicIPAllocationMethod": .properties.publicIPAllocationMethod
      },
      "zones": [
        "1",
        "2",
        "3"
      ]
    }
  ],
  "outputs": {}
}
