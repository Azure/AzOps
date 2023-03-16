del(.properties.internalId,.properties.numberOfRecordSets,.properties.numberOfVirtualNetworkLinks,.properties.numberOfVirtualNetworkLinksWithRegistration) |
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "metadata": {
    "_generator": {
      "name": "AzOps"
    }
  },
  "parameters": {},
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Network/privateDnsZones",
      "name": .name,
      "apiVersion": "2020-06-01",
      "location": .location,
      "properties": .properties
    }
  ],
  "outputs": {}
}
