param staName string
param location string = resourceGroup().location

var storageName = '${toLower(staName)}${uniqueString(resourceGroup().id)}'

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
