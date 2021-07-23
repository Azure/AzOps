{
  "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Resources/resourceGroups",
      "name": .ResourceGroupName,
      "apiVersion": "0000-00-00",
      "location": .Location,
      "tags": .Tags,
      "properties": {}
    }
  ],
  "outputs": {}
}
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end