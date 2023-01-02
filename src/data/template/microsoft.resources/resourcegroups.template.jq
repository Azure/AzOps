{
  "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
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
      "type": "microsoft.resources/resourcegroups",
      "name": .name,
      "apiVersion": "0000-00-00",
      "location": .location,
      "tags": .tags,
      "properties": {}
    }
  ],
  "outputs": {}
} |
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end