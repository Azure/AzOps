param policyAssignmentName string = 'TestPolicyAssignmentWithUAM'
param policyDefinitionID string = '/providers/Microsoft.Authorization/policyDefinitions/014664e7-e348-41a3-aeb9-566e4ff6a9df'
param location string = resourceGroup().location
param uamName string = 'TestAzOpsUAM'

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
