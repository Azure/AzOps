param rgName string = 'resourceGroups-azopsrg'
param location ('westeurope' | 'northeurope') = 'northeurope'
targetScope = 'subscription'

resource symbolicname 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: rgName
  location: location
}
