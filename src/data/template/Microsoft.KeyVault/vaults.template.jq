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
            "location": "[resourceGroup().location]",
            "properties": .Properties
        }
    ],
    "outputs": {}
} | .resources [].properties.tenantId="[subscription().tenantId]"
