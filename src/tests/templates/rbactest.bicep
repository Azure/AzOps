param policyAssignmentName string
param policyDefinitionID string
param location string
param roleDefinitionId string
targetScope = 'subscription'

resource assignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
    name: policyAssignmentName
    location: location
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
    roleDefinitionId: roleDefinitionId
  }
}
