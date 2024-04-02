# Prerequisites

AzOps pipelines can use either a Service Principal, or a Managed Identity if running self-hosted build agents hosted in Azure. This guide walks through the prerequisites needed to setup your AzOps pipelines.

## In this guide

- [Steps](#steps)
- [Create Service Principal](#create-service-principal)
- [Azure role assignment](#azure-role-assignment)
- [Azure AD role assignment](#azure-ad-role-assignment)

---

### Steps

- Create a Service Principal
- Assign Azure `Owner` role at the required scope to the Service Principal/Managed Identity
- Add Service Principal/Managed Identity to Azure AD `Directory Readers` role

> Note: Listing Management groups requires that the Azure Resource Provider [Microsoft.Management](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers#management-resource-providers) is [registered in the Azure Subscription](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider) where AzOps is initialized, this will occur automatically if the Service Principal for AzOps have the correct permissions. Otherwise the Microsoft.Management provider will have to be registered manually. The permission to register Resource providers are included in the Owner and Contributor roles.

The Azure Active Directory [Directory Readers](https://learn.microsoft.com/azure/active-directory/roles/permissions-reference#directory-readers) role is required to discover Azure 'roleAssignments'. These permissions are used to enrich data around the role assignments with additional Azure AD context such as `ObjectType` and Azure AD object `DisplayName`.

> Theses steps require PowerShell 7 and _Az.Accounts_, _Az.Resources_, _Microsoft.Graph.Applications_ and _Microsoft.Graph.Identity.DirectoryManagement_ modules, they will be installed.

---

### Create Service Principal

If you intend to run AzOps with hosted agents a Service Principal is required. Perform the steps below to create the Service Principal in Azure AD. If you plan to run with self-hosted agents and want to use a managed identity skip to the next step.
If using GitHub Enterprise Cloud or Azure DevOps Pipelines, consider using [federated credentials](https://github.com/azure/azops/wiki/oidc) to eliminate secrets management.

```powershell
# Install module
Install-Module Az.Accounts, Az.Resources

# Connect to Azure
Connect-AzAccount

# Create Service Principal
$servicePrincipalDisplayName = "<name of service principal>"
$servicePrincipal = New-AzADServicePrincipal -DisplayName $servicePrincipalDisplayName

Write-Host "ARM_TENANT_ID: $((Get-AzContext).Tenant.Id)"
Write-Host "ARM_SUBSCRIPTION_ID: $((Get-AzContext).Subscription.Id)"
Write-Host "ARM_CLIENT_ID: $($servicePrincipal.AppId)"
Write-Host "ARM_CLIENT_SECRET: $($servicePrincipal.PasswordCredentials.SecretText)" # Not required when using federated credentials or managed identities
```

> Save the output from the script for later, it will be used when creating variables for your pipelines.

### Azure role assignment

#### Assign Azure role to root (/) scope

If you want to manage your entire Azure landscape using AzOps, assign the `Owner` role at the root `(/)` scope.

```powershell
# Install module
Install-Module Az.Accounts, Az.Resources

# Connect to Azure
Connect-AzAccount

# Assign permissions at root scope
$servicePrincipalDisplayName = '<name of service principal or resource with MI enabled>'
$roleToAssign = 'Owner'
$ErrorActionPreference = 'Stop'
$servicePrincipal = Get-AzADServicePrincipal -DisplayName $servicePrincipalDisplayName
New-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName $roleToAssign -Scope '/'
```

> You may need to [elevate your access](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin) in Azure before being able to create a root scoped assignment.

#### Assign Azure role to management group scope

If you intend to only manage a subset of your Azure landscape, you can assign permissions at management group scope instead of root. Use the script below to assign permissions at management group level.

```powershell
# Install module
Install-Module Az.Accounts, Az.Resources

# Connect to Azure
Connect-AzAccount

# Assign permissions at management group scope
$servicePrincipalDisplayName = '<name of service principal or resource with MI enabled>'
$roleToAssign = 'Owner'
$managementGroupName = '<ManagementGroupName>'

$ErrorActionPreference = 'Stop'
$servicePrincipal = Get-AzADServicePrincipal -DisplayName $servicePrincipalDisplayName
$managementGroup = Get-AzManagementGroup -GroupId $managementGroupName
New-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName $roleToAssign -Scope $managementGroup.Id
```

### Azure AD role assignment

If you intend to pull back roleAssignments or roleEligibilityScheduleRequests (PIM eligible assignments), assign the `Directory Readers` role to the Service Principal or Managed Identity.

> Note: Since AzOps [release 1.9.2](https://github.com/Azure/AzOps/releases/tag/1.9.1), roleAssignments without the enriched properties `DisplayName` and `ObjectType` will be pulled without the `Directory Readers` Azure AD role assigned.

```powershell
# Install module
Install-Module Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Applications

# Connect to Azure Active Directory
Connect-MgGraph -Scopes "Directory.Read.All,RoleManagement.ReadWrite.Directory"

# Get Service Principal from Azure Active Directory
$servicePrincipalDisplayName = "<name of service principal or resource with MI enabled>"
$servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$servicePrincipalDisplayName'"
if (-not $servicePrincipal) {
    Write-Error "$servicePrincipalDisplayName Service Principal not found"
}

# Add Azure Active Directory Role Member
$directoryRoleDisplayName = "Directory Readers"
$directoryRole = Get-MgDirectoryRole -Filter "DisplayName eq '$directoryRoleDisplayName'"
if (-not $directoryRole) {
    Write-Warning "$directoryRoleDisplayName role not found"
} else {
    $body = @{'@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($servicePrincipal.Id)"}
    New-MgDirectoryRoleMemberByRef -DirectoryRoleId $directoryRole.id -BodyParameter $body
}
```

> If you receive a warning message "Directory Readers role not found."  this can occur when the role has not yet been used in your directory.
> As a workaround, assign the role manually to the AzOps App from the Azure portal.