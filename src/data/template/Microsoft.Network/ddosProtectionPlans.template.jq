{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "virtualNetworks": {
          "type": "array",
          "defaultValue": .properties.virtualNetworks
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/ddosProtectionPlans",
      "name": "gs-co-ddos-eastus",
      "apiVersion": "2022-11-01",
      "location": .location,
      "properties": {
        "virtualNetworks": "[parameters('virtualNetworks')]"
      }
    }
  ],
  "outputs": {}
}
