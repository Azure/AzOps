# Use Workload identity federation with the AzOps GitHub Actions

- [Introduction](#Introduction)
- [Configure](#Configure)
- [Resources](#Resources)

## Introduction

GitHub Actions now supports OpenID Connect (OIDC) for secure deployments to Azure, which uses short-lived tokens that are automatically rotated for each deployment. 
In the context of AzOps, this means we can allow the AzOps pipeline SPNs to access Azure Resource Manager and Azure AD with federated credentials, elimiating the need to create/handle secrets in the repository. 

This wiki explains how this feature can be configured and used in the AzOps pipelines.

> Note: The Workload identity federation feature identity feature is currently in preview. When the feature is GA we will change the default behavior of our pipelines to take a dependency of this feature. 

## Configure

### Azure AD

### Github Actions 

## Resources
Read more about the functionality in the official docs below: 

* [Azure AD Workload identity federation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
* [GitHub Actions: Secure cloud deployments with OpenID Connect](https://github.blog/changelog/2021-10-27-github-actions-secure-cloud-deployments-with-openid-connect/)