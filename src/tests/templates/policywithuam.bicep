param policyAssignmentName string
param policyDefinitionID string
param location string = resourceGroup().location
param uamName string

targetScope = 'resourceGroup'

resource uam 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
    name: uamName
    location: location
}

resource assignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
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
