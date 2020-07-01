**AzOps**

Status: _Out of Sync_

Description:

_The repository does not contain the latest Azure Resource Manager state, remediation is required before merging of the Pull Request can complete._

Remediation:

You can [re-initialize](https://github.com/Azure/Enterprise-Scale/blob/main/docs/Deploy/setup-azuredevops.md#discover-environment) your repository to pull latest changes from Azure by invoking GitHub Action. You can monitor the status of the GitHub Action in `Pipelines` section. Upon successful completion, this will create a new `system` branch and Pull Request containing changes with latest configuration. Name of the Pull Request will be `Azure Change Notification`.

- 1. Please merge Pull Request from `system`  branch in to your `main` branch.
- 2. Update you feature branch from  main `git pull origin/main`
- 3. Push your branch to `origin` by running following command `git push`

Please manually run the AzOps pipeline, setting the `DoPull` variable to `true`
