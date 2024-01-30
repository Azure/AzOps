targetScope = 'subscription'

param resourceGroupName string
param location string

resource myRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {}
  properties: {}
}
