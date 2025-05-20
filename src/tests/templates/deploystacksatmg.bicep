targetScope = 'managementGroup'

param policyDefinitionIdstring string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'stacks-audit-vm-disks'
  properties: {
    displayName: 'Audit VMs with managed disks'
    policyDefinitionId: policyDefinitionIdstring
  }
}
