param name string
param staName string
param location string = resourceGroup().location

var storageName = '${toLower(staName)}${uniqueString(resourceGroup().id)}'

resource rt 'Microsoft.Network/routeTables@2024-05-01' = {
  name: name
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
    ]
  }
}

resource storage_resource 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GZRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}
