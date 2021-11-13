# Use Workload identity federation with the AzOps GitHub Actions

- [Introduction](#Introduction)
- [Configure](#Configure)
- [Resources](#Resources)

## Introduction

GitHub Actions now supports OpenID Connect (OIDC) for secure deployments to Azure, which uses short-lived tokens that are automatically rotated for each deployment. 
In the context of AzOps, this means we can allow the AzOps pipeline SPNs to access Azure Resource Manager and Azure AD with federated credentials, elimiating the need to create/handle secrets in the repository. 

This wiki explains how this feature can be configured and used in the AzOps pipelines. 

> **Important**: To make this feature work with the current implementation of Workload identities, we take a dependency on [Environments for Github Actions](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment).<br>
*Environments are only available in public repositories for free. Access to environments in private repositories requires [GitHub Enterprise](https://docs.github.com/en/get-started/learning-about-github/githubs-products#github-enterprise).*

> **Note:** The Workload identity federation feature identity feature is currently in preview. Features and implementation details may change in the future.

## Configure
Before you start to configure the workload federation feature in Azure AD and changing the GitHub Actions, ensure that you have followed the instructions at https://github.com/azure/azops/wiki/prerequisites and have your service principal ready with appropriate RBAC permissions.

### Azure AD
1. In Azure AD, find your AzOps service principal and navigate to Certificates & Secrets -> Federated credentials. 
    ![Add creds](./Media/oidc/spn_addcreds.jpg)
2. Add federated credentials to the Service Principal. Replace the values to reflect your organization, repository and environment name. In the accelerator examples, we have used 'prod' as the environment enable. 
    ![Overview](./Media/oidc/spn_addcreds2.jpg)
    ![Overview](./Media/oidc/spn_added.jpg)
### Github Actions 

## Resources
Read more about the functionality in the official docs below: 

* [Azure AD Workload identity federation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
* [GitHub Actions: Secure cloud deployments with OpenID Connect](https://github.blog/changelog/2021-10-27-github-actions-secure-cloud-deployments-with-openid-connect/)