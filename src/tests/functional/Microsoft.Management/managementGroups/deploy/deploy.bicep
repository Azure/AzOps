param managementGroupName string = 'AzOpsMGMTName'
param managementGroupId string = 'AzOpsMGMTID'

targetScope = 'tenant'

resource managementGroup 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: managementGroupId
  properties: {
    displayName: managementGroupName
  }
}
