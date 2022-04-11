param policyAssignmentName string = 'audit-vm-manageddisks-fn'
param policyDefinitionID string = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'

targetScope = 'subscription'

resource assignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
    name: policyAssignmentName
    properties: {
        policyDefinitionId: policyDefinitionID
    }
}

output assignmentId string = assignment.id
