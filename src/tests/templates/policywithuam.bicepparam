using './policywithuam.bicep'

param policyAssignmentName = 'TestPolicyAssignmentWithUAM'
param policyDefinitionID = '/providers/Microsoft.Authorization/policyDefinitions/014664e7-e348-41a3-aeb9-566e4ff6a9df'
param uamName = 'TestAzOpsUAM'
