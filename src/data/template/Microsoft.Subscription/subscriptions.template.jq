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
            "type": .Type,
            "name": .Name,
            "apiVersion": "0000-00-00",
            "tags": .Tags
        }
    ],
    "outputs": {}
} |
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end
| del(.. | select(. == null))
| del(.. | select(. == ""))