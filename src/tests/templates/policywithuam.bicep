param policyAssignmentName string
param policyDefinitionID string
param location string = resourceGroup().location
param uamName string

targetScope = 'resourceGroup'

resource uam 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
    name: uamName
    location: location
}

resource assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
    name: policyAssignmentName
    location: location
    identity: {
        type: 'UserAssigned'
        userAssignedIdentities: {
            '${uam.id}': {}
        }
    }
    properties: {
        policyDefinitionId: policyDefinitionID
    }
}
