param roleDefinitionResourceId string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
param principalId string = '4dacdaa1-2044-490c-a603-36f80b6aaa0c'

targetScope = 'subscription'

@description('This is the built-in Reader role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader')
resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: roleDefinitionResourceId
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: principalId
    principalType: 'User'
  }
}

output roleAssignmentName string = roleAssignment.name
