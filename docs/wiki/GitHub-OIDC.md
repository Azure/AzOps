# Use Workload identity federation with the AzOps GitHub Actions

- [Introduction](#introduction)
- [Configure](#configure)
- [Resources](#resources)

## Introduction

GitHub Actions now supports OpenID Connect (OIDC) for secure deployments to Azure, which uses short-lived tokens that are automatically rotated for each deployment.
In the context of AzOps, this means we can allow the AzOps pipeline SPNs to access Azure Resource Manager and Azure AD with federated credentials, eliminating the need to create/handle secrets in the repository.

This wiki explains how this feature can be configured and used in the AzOps GitHub Actions.

> **Important**: To make this feature work with the current implementation of Workload identities, we take a dependency on [Environments for GitHub Actions](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment). *Environments are only available in public repositories for free. Access to environments in private repositories requires [GitHub Enterprise](https://docs.github.com/en/get-started/learning-about-github/githubs-products#github-enterprise).*

## Configure

Before you start to configure the workload federation feature in Azure AD and changing the GitHub Actions, ensure that you have followed the instructions at <https://github.com/azure/azops/wiki/prerequisites> and have your service principal ready with appropriate RBAC permissions.

### Azure AD

1. In Azure AD, find your AzOps service principal and navigate to Certificates & Secrets -> Federated credentials.
    ![Add creds](./Media/oidc/spn_addcreds.jpg)
2. Add federated credentials to the Service Principal. Replace the values to reflect your organization, repository and environment name. In the accelerator examples, we have used 'prod' as the environment enable.
    ![Overview](./Media/oidc/spn_addcreds2.jpg)
    ![Overview](./Media/oidc/spn_added.jpg)

### Github Actions
>
> **Note:** The starter GitHub pipelines in [AzOps-Accelerator](https://github.com/azure/azops-accelerator) have been adapted to support federated credentials. If you haven't updated the pipelines recently, consider performing an update using the [update](https://github.com/azure/azops/wiki/updates) pipeline.

1. Validate that you have the latest version (post february 2023) of [sharedSteps/action.yml](https://github.com/Azure/AzOps-Accelerator/tree/main/.github/actions/sharedSteps), [pull.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/pull.yml), [push.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/push.yml), [redeploy.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/redeploy.yml) and [validate.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/validate.yml).
2. Uncomment the line with environment definition in [pull.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/pull.yml), [push.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/push.yml), [redeploy.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/redeploy.yml) and [validate.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows/validate.yml). Change the environment name to reflect your environment names.

    ```yaml
        environment: prod # Environment if using Federated Credentials (https://github.com/azure/azops/wiki/github-oidc)
    ```

3. Remove all references to `ARM_CLIENT_SECRET` from the repository/environment secrets. If `ARM_CLIENT_SECRET` exists, the pipeline will try to connect with the secret instead.

    ![Overview](./Media/oidc/arm_client_secret.png)
4. Test the Pull, Pull and Validate pipelines to ensure authentication works with the federated credentials.

## Resources

Read more about the functionality in the official docs below:

- [Azure AD Workload identity federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [GitHub Actions: Secure cloud deployments with OpenID Connect](https://github.blog/changelog/2021-10-27-github-actions-secure-cloud-deployments-with-openid-connect/)
