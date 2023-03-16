del(.properties.defaultSecurityRules[].etag, .properties.defaultSecurityRules[].id) |
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {
    "subnets": {
        "type": "array",
        "defaultValue": .properties.subnets
    }
  },
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/networkSecurityGroups",
      "name": .name,
      "apiVersion": "2022-11-01",
      "location": .location,
      "properties": {
        "defaultSecurityRules": .properties.defaultSecurityRules,
        "securityRules": .properties.securityRules,
        "subnets": "[parameters('subnets')]"
      }
    }
  ],
  "outputs": {}
}
