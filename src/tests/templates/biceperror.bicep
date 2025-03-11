param staName string = 'eroazops${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location

resource storage_resource 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: staName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties000: {
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'None'
      defaultOction: 'MaybeGivesError'
    }
    supportsHttpsTrafficOnly: true
  }
}
