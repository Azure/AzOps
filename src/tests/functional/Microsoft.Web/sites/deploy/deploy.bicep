param webAppName string = uniqueString(resourceGroup().id)
param sku string = 'S1'
param linuxFxVersion string = 'node|14-lts'
param location string = resourceGroup().location

var appServicePlanName = toLower('AppServicePlan-${webAppName}')
var webSiteName = toLower('azapp-${webAppName}')

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
resource appService 'Microsoft.Web/sites@2021-03-01' = {
  name: webSiteName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersion
    }
  }
}

output webSiteName string = appService.name
