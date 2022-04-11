param managementGroupName string = 'AzOpsMGMTName'
param managementGroupId string = 'AzOpsMGMTID'

targetScope = 'tenant'

resource managementGroup 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: managementGroupId
  properties: {
    displayName: managementGroupName
  }
}
