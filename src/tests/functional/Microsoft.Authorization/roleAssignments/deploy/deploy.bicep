param roleDefinitionResourceId string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
param principalId string = '023e7c1c-1fa4-4818-bb78-0a9c5e8b0217'

targetScope = 'subscription'

@description('This is the built-in Reader role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader')
resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: roleDefinitionResourceId
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().id, principalId, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentName string = roleAssignment.name
