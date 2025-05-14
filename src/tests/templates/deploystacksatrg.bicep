param name string = 'rtstackatrg'
param location string = resourceGroup().location

resource symbolicname 'Microsoft.Network/routeTables@2024-05-01' = {
  name: name
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
    ]
  }
}
