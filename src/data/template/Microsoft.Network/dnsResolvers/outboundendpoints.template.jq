{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "subnet": {
        "type": "object",
        "defaultValue": .properties.subnet
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
      "type": "Microsoft.Network/dnsResolvers/outboundendpoints",
      "name": "[variables('name')]",
      "apiVersion": "2022-07-01",
      "location": .location,
      "properties": {
        "subnet": "[parameters('subnet')]"
      }
    }
  ],
  "outputs": {}
}
