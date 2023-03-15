param staName string = 'staazops${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location

resource storage_resource 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: staName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
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
