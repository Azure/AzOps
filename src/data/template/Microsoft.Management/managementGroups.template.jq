{
  "$schema": "https://schema.management.azure.com/schemas/2019-08-01/managementGroupDeploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {},
  "variables": {},
  "resources": [
    {
      "type": "Microsoft.Management/managementGroups",
      "name": .Name,
      "apiVersion": "0000-00-00",
      "scope": "/",
      "properties": {
          "displayName": .DisplayName,
          "details": {
              "parent": {
                  "id": .ParentId
              }
          }
      }
    }
  ],
  "outputs": {}
}
