## AzOps

The 'main' branch in the repository does not contain the latest configuration of Azure.

It is strongly recommended to ensure that 'feature' and 'main' branches contain the current Azure configuration.

### Remediation

[Re-initialize](https://github.com/Azure/Enterprise-Scale/blob/main/docs/Deploy/setup-azuredevops.md#discover-environment) your repository to pull latest changes from Azure by invoking the Azure Pipeline. You can monitor the status of the Pipeline in `Pipelines` section.

Upon successful completion, the action will create a new `system` branch and a new `Azure Change Notification` pull request containing the latest configuration.

- Please merge Pull Request from `system`  branch in to your `main` branch.

- Update you feature branch from  main `git pull origin/main`

- Push your branch to `origin` by running following command `git push`

