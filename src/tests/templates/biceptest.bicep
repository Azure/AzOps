targetScope = 'subscription'
@description('Name of the resource group')
param resourceGroupName string
param location ('westeurope' | 'swedencentral')

resource myRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: {}
  properties: {}
}
