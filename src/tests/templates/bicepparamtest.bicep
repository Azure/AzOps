param name string
param location string

resource symbolicname 'Microsoft.Network/routeTables@2024-05-01' = {
  name: name
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
    ]
  }
}
