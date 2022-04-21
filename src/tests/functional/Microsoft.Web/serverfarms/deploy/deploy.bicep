param appServicePlanName string = uniqueString(resourceGroup().id)
param sku string = 'S1'
param location string = resourceGroup().location

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
  kind: 'linux'
}
