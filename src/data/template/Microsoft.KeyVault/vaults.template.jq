{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.KeyVault/vaults",
            "name": .Name,
            "apiVersion": "2019-09-01",
            "location": .Location,
            "tags": .Tags,
            "properties": .Properties
        }
    ],
    "outputs": {}
} | .resources [].properties.tenantId="[subscription().tenantId]" |
.resources[].tags |= if . != null then to_entries | sort_by(.key) | from_entries else . end