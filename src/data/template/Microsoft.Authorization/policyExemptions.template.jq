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
            "properties": {
                "assignmentScopeValidation": .AssignmentScopeValidation,
                "description": .Description,
                "displayName": .DisplayName,
                "exemptionCategory": .ExemptionCategory,
                "expiresOn": .ExpiresOn,
                "metadata": .Metadata,
                "policyAssignmentId": .PolicyAssignmentId,
                "policyDefinitionReferenceIds": .PolicyDefinitionReferenceIds,
                "resourceSelector": .ResourceSelector,
            }
        }
    ],
    "outputs": {}
}
| del(.. | select(. == null))
| del(.. | select(. == ""))