# Azure Pipelines using Managed Identity

When running AzOps pipelines on self-hosted build agents a [Managed Identity](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview) can be used instead of a Service Principal.

This article covers the steps to assign the required permissions to your Managed Identity, and the changes needed to use a Managed Identity for your pipelines.

## Prerequisites

- Please check if the `Az`, `Microsoft.Graph.Identity.DirectoryManagement` and `Microsoft.Graph.Applications` modules are installed locally before executing these scripts. Alternatively, these command can be run within a Cloud Shell instance.
- An Azure DevOps agent pool running on either a VMSS or an Azure VM with Managed Identity enabled.

### Powershell command to assign owner permissions at root scope

To assign owner permissions at the root `"/"` scope run the script below.

```powershell
$managedIdentityDisplayName = '<name of VMSS or VM>'

Connect-AzAccount
$servicePrincipal=Get-AzADServicePrincipal -displayname $managedIdentityDisplayName
$roleAssignment = New-AzADRoleAssignment -Role 'Owner' -Scope '/' -ObjectId $servicePrincipal.Id
Write-Host "ARM_TENANT_ID: $((Get-AzContext).Tenant.Id)"
Write-Host "ARM_SUBSCRIPTION_ID: $((Get-AzContext).Subscription.Id)"
```

### Powershell command to assign owner permissions at management group scope

AzOps can be configured for partial discovery by specifying a specific management group as partial root. Use the script below to assign permissions at a management group scope instead of root.

```powershell
$managedIdentityDisplayName = '<name of VMSS or VM>'
$roleToAssign = 'Owner'
$managementGroupName = '<ManagementGroupName>'

$ErrorActionPreference = 'Stop'
$managedIdentity = Get-AzADServicePrincipal -SearchString $managedIdentityDisplayName
$role = Get-AzRoleDefinition -Name $roleToAssign
$managementGroup = Get-AzManagementGroup -GroupName $managementGroupName
New-AzRoleAssignment -ObjectId $managedIdentity.Id -RoleDefinitionId $role.Id -Scope $managementGroup.Id
```

### Powershell command to assign the RBAC role permissions to Managed Identity

```powershell
$managedIdentityDisplayName = '<name of VMSS or VM>'

Install-Module Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Applications
Connect-MgGraph -Scopes "Directory.Read.All,RoleManagement.ReadWrite.Directory"
$managedIdentity= Get-MgServicePrincipal -Filter "DisplayName eq '$managedIdentityDisplayName'"
if (-not $managedIdentity) {
    Write-Error "$managedIdentityDisplayName Managed Identity not found" -ErrorAction 'Stop'
}
$directoryRoleDisplayName = "Directory Readers"
$directoryRole = Get-MgDirectoryRole -Filter "DisplayName eq '$directoryRoleDisplayName'"
if (-not $directoryRole) {
    Write-Error "$directoryRoleDisplayName role not found" -ErrorAction 'Stop'
} else {
    $body = @{'@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($managedIdentity.Id)"}
    New-MgDirectoryRoleMemberByRef -DirectoryRoleId $directoryRole.id -BodyParameter $body
}
```

## Configure AzOps to use managed Identity

