param policyAssignmentName string = 'AzOpsDep2 - audit-vm-manageddisks'
param policyDefinitionID string = '/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d'
targetScope = 'subscription'

resource assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
    name: policyAssignmentName
    location: 'northeurope'
    identity: {
      type: 'SystemAssigned'
  }
    properties: {
        policyDefinitionId: policyDefinitionID
    }
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(assignment.id)
  properties: {
    principalId: assignment.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/providers/microsoft.authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
}
