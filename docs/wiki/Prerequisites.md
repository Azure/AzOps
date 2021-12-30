## In this guide

- [Steps](#steps)
- [Azure](#azure)
- [Azure Active Directory](#azure-active-directory)

---

### Steps

- Create Service Principal
- Assign Azure `Owner` role at the required root scope (/) to the Service Principal
- Add Service Principal to Azure Active Directory `Directory Readers` role

The Service Principal requires Azure Active Directory [Directory Readers](https://docs.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#directory-readers) role to discover Azure 'roleAssignments'. These permissions are used to enrich data around the role assignments with additional Azure AD context such as ObjectType and Azure AD Object DisplayName.

> Theses steps require PowerShell 7 and _Az.Accounts, Az.Resources_ and _Microsoft.Graph.Identity.DirectoryManagement_ modules, they will be installed.

---

### Azure

> You may need to elevate your access in Azure before being able to create a root scoped assignment.

```powershell
#
# Install module
#

Install-Module Az.Accounts, Az.Resources

#
# Connect to Azure
#

Connect-AzAccount

#
# Create Service Principal and assign
# 'Owner' role at tenant root scope '/'
#

$servicePrincipalDisplayName = "AzOps"
$servicePrincipal = New-AzADServicePrincipal -Role Owner -Scope / -DisplayName $servicePrincipalDisplayName

#
# Display the generated Service Principal
#

Write-Host "ARM_TENANT_ID: $((Get-AzContext).Tenant.Id)"
Write-Host "ARM_SUBSCRIPTION_ID: $((Get-AzContext).Subscription.Id)"
Write-Host "ARM_CLIENT_ID: $($servicePrincipal.ApplicationId)"
Write-Host "ARM_CLIENT_SECRET: $($servicePrincipal.Secret | ConvertFrom-SecureString -AsPlainText)"
```

---

### Azure Active Directory

```powershell
#
# Install module
#

Install-Module Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Applications

#
# Connect to Azure Active Directory
#

Connect-MgGraph -Scopes "Directory.Read.All,RoleManagement.ReadWrite.Directory"

#
# Get Service Principal from Azure Active Directory
#

$servicePrincipalDisplayName = "AzOps"
$servicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq '$servicePrincipalDisplayName'"
if (-not $servicePrincipal) {
    Write-Error "$servicePrincipalDisplayName Service Principal not found"
}

#
# Add Azure Active Directory Role Member
#

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
> As a workaround, assigning the role manually to the AzOps App from the Azure portal
