{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "firewalls": {
        "type": "array",
        "defaultValue": .properties.firewalls
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/firewallPolicies",
      "name": .name,
      "apiVersion": "2022-11-01",
      "location": .location,
      "properties": {
        "childPolicies": [],
        "firewalls": "[parameters('firewalls')]",
        "ruleCollectionGroups": [],
        "sku": {
          "tier": "Standard"
        },
        "threatIntelMode": "Alert"
      }
    }
  ],
  "outputs": {}
}
