_Coming soon_

### In this guide

- [Commands](#commands)
- [Portal](#portal)
  - [Create the project](#create-project)
  - [Import the repository](#import-repository)
  - [Remove actions directory](#remove-actions-directory)
  - [Configure the pipelines](#configure-pipelines)
  - [Configure the permissions](#configure-permissions)
  - [Configure the branch polices](#configure-branch-policies)

---

## Commands

The following commands require the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/) and the [DevOps Extension](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops).

> Before running the following commands, the '(replace)' values need to be updated.  
> Manual step required is to add the permissions within the UI on the repository for the build service.

Project - _Create the new project within a specific organization_

```bash
az devops project create \
    --name '(replace)' --organization '(replace)'
```

Defaults - _Set the defaults for the local Azure Cli shell_

```bash
az devops configure \
    --defaults organization=https://dev.azure.com/'(replace)' project='(replace)'
```

Import - _Create a new repository from the upstream template repository_

```bash
az repos import create \
    --git-url https://github.com/azure/azops.git --repository '(replace)'
```

Pipelines - _Create two new pipelines from existing YAML manifests_

```bash
az pipelines create \
    --name 'AzOps - Pull' --branch main --repository '(replace)' --repository-type tfsgit --yaml-path .pipelines/pull.yml

az pipelines create \
    --name 'AzOps - Push' --branch main --repository '(replace)' --repository-type tfsgit --yaml-path .pipelines/push.yml
```

Variables - _Add secrets for authenticating pipelines with Azure Resource Manager_

```bash
az pipelines variable create \
    --name 'ARM_TENANT_ID' --pipeline-name 'AzOps - Pull' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_SUBSCRIPTION_ID' --pipeline-name 'AzOps - Pull' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_CLIENT_ID' --pipeline-name 'AzOps - Pull' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_CLIENT_SECRET' --pipeline-name 'AzOps - Pull' --secret true --value '(replace)'

az pipelines variable create \
    --name 'ARM_TENANT_ID' --pipeline-name 'AzOps - Push' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_SUBSCRIPTION_ID' --pipeline-name 'AzOps - Push' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_CLIENT_ID' --pipeline-name 'AzOps - Push' --secret false --value '(replace)'

az pipelines variable create \
    --name 'ARM_CLIENT_SECRET' --pipeline-name 'AzOps - Push' --secret true --value '(replace)'
```

Policy - _Add build validation policy to push changes_

```bash
az pipelines show \
    --name 'AzOps - Push'

az repos policy build create \
    --blocking true \
    --branch main \
    --display-name 'Push' \
    --enabled true \
    --build-definition-id (replace) \
    --repository-id (replace) \
    --queue-on-source-update-only false \
    --manual-queue-only false \
    --valid-duration 0
```

---

### Portal

#### Create project

Browse to [Azure DevOps](https://dev.azure.com), authenticate to the organisation and create a new _Private_ or _Enterprise_ project.

Ensure that the Version Control is selected with *Git*

![Create the project](./Media/Pipelines/Project-Creation.png)

#### Import repository

Within the newly created project, import the template repository from GitHub.

Provide the Clone URL of the AzOps Accelerator repository.

![Import the repository parameters](./Media/Pipelines/Import-Repository.png)

Additional documentation can be found [here](https://docs.microsoft.com/azure/devops/repos/git/import-git-repository).

#### Remove actions directory

As this deployment will be configured for Azure Pipelines it is safe to delete the `.github` folder.

![Actions](./Media/Pipelines/Delete-Actions.png)

#### Configure pipelines

Create two new pipelines, selecting the existing files:

- .pipelines/pull.yml
- .pipelines/push.yml

It's recommended to name these pipelines `AzOps - Pull` and `AzOps - Push` respectively (in both the YAML file, *and* within the pipeline after you create it).

![Create the pipelines](./Media/Pipelines/Pipeline-Creation.png)

After creating the pipelines, create a new Variable Group by navigating to `Library`.

Set the name of Variable Groups to `Credentials`. This can be altered but the value in the pipelines will need to be updated.

Add the variables from the Service Principal creation.

![Create the variable group](./Media/Pipelines/Variable Group.png)

- ARM_TENANT_ID
- ARM_SUBSCRIPTION_ID
- ARM_CLIENT_ID
- ARM_CLIENT_SECRET

Define the `ARM_CLIENT_SECRET` as a secret.

These variables will used to authenticate with Azure.

Please see the [scripts](#scripts) section for ways to implement the variables with Azure CLI.

#### Configure permissions

The build service account must have the following permissions on the repository:

- `Contribute`
- `Contribute to pull requests`
- `Create branch`

Navigate to the project settings, within the *Repos* section, select *Repositories*, select the newly created repository.

Select the *[Project] Build Service ([Organization])* account, and configure the permissions above.

![Configure the Repository Permissions](./Media/Pipelines/Repository-Permissions.png)

#### Configure branch policies

In order for the `AzOps - Push` pipeline to run, set the repository `main` branch to [require build verification](https://docs.microsoft.com/azure/devops/repos/git/branch-policies) using most of default settings, but do define a path filter `/azops/*`.

![Build Policy](./Media/Pipelines/Branch-Policies.png)

It is also recommend to allow only `squash` merge types from branches into `main`.

![Repo policy](./Media/Pipelines/Merge-Types.png)
