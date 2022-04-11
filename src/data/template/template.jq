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
            "type": .ResourceType,
            "name": .Name,
            "sku": .Sku,
            "kind": .Kind,
            "apiVersion": "0000-00-00",
            "location": .Location,
            "tags": .Tags,
            "properties": .Properties
        }
    ],
    "outputs": {}
} |
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end
| del(.resources[].sku | nulls)
| del(.resources[].kind | nulls)
