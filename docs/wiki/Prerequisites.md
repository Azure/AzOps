## In this guide

- [Steps](#steps)
- [Azure](#discovery)
- [Azure Active Directory](#azuread)

---

### Steps

- Create the Service Principal
- Assign the permissions at the required scope (/)
- Assign the Directory role permissions

Please check if the _Az_ and _AzureAD_ modules are installed locally before executing these scripts. 
Alternatively, these command can be run within a Cloud Shell instance.

---

### Azure

> You may need to elevate your access in Azure before being able to create a root scoped assignment.

```powershell
#
# Install module
#

Install-Module -Name Az

#
# Connect to Azure
#

Connect-AzAccount

#
# Create Service Principal and assign
# 'Owner' role to tenant root scope '/'
#

$servicePrincipal = New-AzADServicePrincipal -Role Owner -Scope / -DisplayName AzOps

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

Install-Module -Name AzureAD

#
# Connect to Azure Active Directory
#

Connect-AzureAD

#
# Get Service Principal from Azure AD
#

$servicePrincipal = Get-AzureADServicePrincipal -Filter "DisplayName eq 'AzOps'"

#
# Assign Azure AD Directory Role
#

$directoryRole = Get-AzureADDirectoryRole -Filter "DisplayName eq 'Directory Readers'"
if ($directoryRole -eq $null) {
    Write-Warning "Directory Reader role not found"
}
else {
    Add-AzureADDirectoryRoleMember -ObjectId $directoryRole.ObjectId -RefObjectId $servicePrincipal.ObjectId
}
```

> If you receiving the warning message "Directory Reader role not found."  this usually occurs when the role has not yet been used in your directory.
> As a workaround, try assigning this role manually to the AzOps App in the Azure portal
