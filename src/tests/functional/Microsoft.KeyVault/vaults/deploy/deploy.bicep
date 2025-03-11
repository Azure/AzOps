param vaultName string = 'kvazopstest${uniqueString(resourceGroup().id)}'
param location string = resourceGroup().location

resource key_vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
    name: vaultName
    location: location
    properties: {
      sku: {
        family: 'A'
        name: 'standard'
      }
      tenantId: subscription().tenantId
      enableRbacAuthorization: true
      enableSoftDelete : false
    }
}
