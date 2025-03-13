targetScope = 'subscription'

param resourceGroupName string
param location string

resource myRg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: {}
  properties: {}
}
