. | . as $input |

[foreach .Children[] as $item ([[],[]];

if $item.Type == "/providers/Microsoft.Management/managementGroups"
then
{
    "type": "Microsoft.Management/managementGroups",
    "apiVersion": "2020-05-01",
    "name": $item.Name,
    "scope": "/",
    "properties": {
        "displayName": $item.DisplayName,
        "details": {
            "parent": {
                "id": ($input.Type + "/" + $input.Name)
            }
        }
    }
}
elif $item.Type == "/subscriptions"
then
{
    "type": "Microsoft.Management/managementGroups/subscriptions",
    "apiVersion": "2021-04-01",
    "name": ($input.Name + "/" + $item.Name),
    "scope": "/"
}
else
empty
end

)] as $resources |

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
    },
    {
      "type": "Microsoft.Resources/deployments",
      "apiVersion": "2020-10-01",
      "name": "Microsoft.Management.Nested",
      "location": "northeurope",
      "properties": {
        "mode": "Incremental",
        "template": {
          "$schema": "https://schema.management.azure.com/schemas/2019-08-01/tenantDeploymentTemplate.json#",
          "contentVersion": "1.0.0.0",
          "resources": $resources,
          "outputs": {}
        }
      },
      "dependsOn": [
        (.Type + "/" + .Name)
      ]
    }
  ],
  "outputs": {}
}
