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
            "apiVersion": "0000-00-00",
            "location": .Location,
            "identity": .Identity,
            "properties": .Properties
        }
    ],
    "outputs": {}
} | .resources[] |= if .identity==null then del(.identity) elif .identity.UserAssignedIdentities==null then del(.identity.UserAssignedIdentities) else . end | 
.resources[] |= if .identity.IdentityType !=null then .identity["Type"] = .identity.IdentityType | del(.identity.IdentityType) else . end |
.resources[] |= if .identity.UserAssignedIdentities != null then del(.identity.UserAssignedIdentities[].PrincipalId, .identity.UserAssignedIdentities[].ClientId, .identity.TenantId, .identity.PrincipalId) else . end
