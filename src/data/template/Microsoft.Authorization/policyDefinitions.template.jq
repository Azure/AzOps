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
            "name": .name,
            "apiVersion": "2021-06-01",
            "properties": {
                "description": .properties.description,
                "displayName":  .properties.displayName,
                "metadata": {
                    "version": .properties.metadata.version,
                    "category": .properties.metadata.category
                },
                "mode": .properties.mode,
                "parameters": .properties.parameters,
                "policyRule": .properties.policyRule | walk(if type == "string" and (.|startswith("[")) then "[" + sub("^\\["; "[") else . end),
                "policyType": .properties.policyType
            }
        }
    ],
    "outputs": {}
}