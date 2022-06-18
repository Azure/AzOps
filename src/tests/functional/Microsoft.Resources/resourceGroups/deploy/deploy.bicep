param rgName string = 'resourceGroups-azopsrg'
param location string = 'northeurope'
targetScope = 'subscription'

resource symbolicname 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}
