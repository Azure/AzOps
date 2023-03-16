del(.properties.ipConfigurations[].etag, .properties.ipConfigurations[].id, .properties.ipConfigurations[].properties.provisioningState) |
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "firewallPolicy": {
        "type": "object",
        "defaultValue": .properties.firewallPolicy
    },
    "ipConfigurations": {
        "type": "array",
        "defaultValue": .properties.ipConfigurations
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/azureFirewalls",
      "name": "gs-co-fw-eastus",
      "apiVersion": "2022-11-01",
      "location": .location,
      "properties": {
        "additionalProperties": .properties.additionalProperties,
        "applicationRuleCollections": .properties.applicationRuleCollections,
        "firewallPolicy":  "[parameters('firewallPolicy')]",
        "ipConfigurations": "[parameters('ipConfigurations')]",
        "natRuleCollections": .properties.natRuleCollections,
        "networkRuleCollections": .properties.networkRuleCollections,
        "sku": {
          "name": "AZFW_VNet",
          "tier": "Standard"
        },
        "threatIntelMode": "Alert"
      }
    }
  ],
  "outputs": {}
}
