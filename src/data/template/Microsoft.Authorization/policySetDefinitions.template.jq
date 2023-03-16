del(.properties.policyDefinitions[].definitionVersion, .properties.policyDefinitions[].effectiveDefinitionVersion, .properties.policyDefinitions[].latestDefinitionVersion) |
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
            "name": .name,
            "apiVersion": "2021-06-01",
            "properties": {
                "description": .properties.description,
                "displayName":  .properties.displayName,
                "metadata": {
                    "version": .properties.metadata.version,
                    "category": .properties.metadata.category
                },
                "parameters": .properties.parameters,
                "policyDefinitionGroups" : .properties.policyDefinitionGroups,
                "policyDefinitions": .properties.policyDefinitions | walk(if type == "string" and (.|startswith("[")) then "[" + sub("^\\["; "[") else . end)
            }
        }
    ],
    "outputs": {}
}