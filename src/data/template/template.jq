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
            "type": .type,
            "name": .name,
            "sku": .sku,
            "kind": .kind,
            "apiVersion": "0000-00-00",
            "location": .location,
            "identity": .identity,
            "tags": .tags,
            "properties": .properties,
            "zones": .zones
        }
    ],
    "outputs": {}
} |
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end
| del(.. | select(. == null))
| del(.. | select(. == ""))
| del (.resources[].properties.extended)