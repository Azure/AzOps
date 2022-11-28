# AzOps via Azure Pipelines

- [Prerequisites](#prerequisites)
  - [Further reading](#further-reading)
  - [Important Repository Link to refer](#important-repository-link-to-refer)
- [Configure AzOps using Azure CLI in PowerShell](#configure-azops-using-azure-cli-in-powershell)
- [Configure AzOps via Azure DevOps Portal](#configure-azops-via-azure-devops-portal)
- [Configuration, clean up and triggering the pipelines](#configuration-clean-up-and-triggering-the-pipelines)

## Prerequisites

Before you start, make sure you have followed the steps in the [prerequisites](https://github.com/azure/azops/wiki/prerequisites) article to configure the required permissions for AzOps.

### Further reading

Links to documentation for further reading:

- [Create the Service Principal](https://learn.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal)
- [Assign the permissions at the required scope (/)](https://learn.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal)
- [Assign the Directory role permissions](https://learn.microsoft.com/azure/active-directory/roles/manage-roles-portal)
- [Create Azure DevOps project](https://learn.microsoft.com/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page)

### Important Repository link to refer

| Repository                                                            | Description                                                                               |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [AzOps Accelerator](https://github.com/Azure/AzOps-Accelerator.git) | This template repository is for getting started with the AzOps integrated CI/CD solution. |

## Configure AzOps using Azure CLI in PowerShell

The PowerShell script below will set up a new project or use an existing if it already exists. The account used to sign in with Azure CLI need to have access to create projects in Azure DevOps or have the owner role assigned to an existing project.

- The script will:
  - Create a new repository and import the official [AzOps Accelerator](https://github.com/Azure/AzOps-Accelerator.git) repository
  - Add a variable group called `credentials`
  - Create pipelines for `Push`, `Pull` and `Validate`
  - Add a build validation policy to the main branch triggering the Validate pipeline on Pull Requests
  - Add a branch policy to limit merge types to squash only
  - Assign permissions to the built-in Build Service account to contribute, open Pull Requests and bypass policies when completing pull requests (to bypass validation pipeline and any approval checks)
  - Assign pipeline permissions for the variable group to each of the pipelines

<br/>

- Install dependent tools & extensions
  - [Azure CLI](https://learn.microsoft.com/cli/azure/)
  - [DevOps Extension](https://learn.microsoft.com/azure/devops/cli/?view=azure-devops)

<br/>

- Sign in to Azure CLI with an account that has access to create projects in Azure DevOps or have the owner role assigned to an existing project
  - `az login`

<br/>

- Before running the commands below, any `<Value>` needs to be replaced with your values

> If you are running self-hosted build agents in Azure with Managed Identity enabled set the value for `$ARM_CLIENT_ID` and `$ARM_CLIENT_SECRET` to `''`.

```PowerShell
# Configuration, make sure to replace <Value> with your values
$Organization = '<Value>'
$ProjectName = '<Value>'
$RepoName = '<Value>'
$TenantId = '<Value>'
$SubscriptionId = '<Value>'
$ARM_CLIENT_ID = '<Value>'
$ARM_CLIENT_SECRET = '<Value>'

# Create a new project
$Project = az devops project list --query "value[?name=='$ProjectName'].{name:name, id:id}" --organization "https://dev.azure.com/$Organization" | ConvertFrom-Json
if ($null -eq $Project) {
    $Project = az devops project create --name $ProjectName --organization "https://dev.azure.com/$Organization" `
        --query "{name:name, id:id}" | ConvertFrom-Json
}

# Set the defaults for the local Azure Cli shell
az devops configure `
    --defaults organization="https://dev.azure.com/$Organization" project="$ProjectName"

# Create a new repository from the AzOps Accelerator template repository
$Repo = az repos list --query "[?name=='$RepoName'].{name:name, id:id}" | ConvertFrom-Json
if ($null -eq $Repo) {
    $Repo = az repos create --name $RepoName --query "{name:name, id:id}" | ConvertFrom-Json
}
az repos import create `
    --git-url "https://github.com/Azure/AzOps-Accelerator.git" --repository "$($Repo.name)"
$null = az repos update --repository $RepoName --default-branch 'main'

# Add a variable group for authenticating pipelines with Azure Resource Manager and record the id output
if ($ARM_CLIENT_SECRET) {
    $VariableGroupId = az pipelines variable-group create `
        --name 'credentials' `
        --variables `
        "ARM_TENANT_ID=$TenantId" "ARM_SUBSCRIPTION_ID=$SubscriptionId" "ARM_CLIENT_ID=$ARM_CLIENT_ID" `
        --query 'id'
} else {
    $VariableGroupId = az pipelines variable-group create `
        --name 'credentials' `
        --variables `
        "ARM_TENANT_ID=$TenantId" "ARM_SUBSCRIPTION_ID=$SubscriptionId" "ARM_CLIENT_ID=$ARM_CLIENT_ID" "ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET" `
        --query 'id'
}

$ConfigVariableGroupId = az pipelines variable-group create `
        --name 'azops' `
        --variables `
        "AZOPS_MODULE_VERSION=" "AZOPS_CUSTOM_SORT_ORDER=false" `
        --query 'id'

# Add a secret to the variable group just created using id from above if using service principal
if ($ARM_CLIENT_SECRET) {
    az pipelines variable-group variable create `
        --id $VariableGroupId --name 'ARM_CLIENT_SECRET' --secret true --value $ARM_CLIENT_SECRET
}

# Create three new pipelines from existing YAML manifests.
az pipelines create --skip-first-run true `
    --name 'AzOps - Push'     --branch main --repository "$RepoName" --repository-type tfsgit --yaml-path .pipelines/push.yml

az pipelines create --skip-first-run true `
    --name 'AzOps - Pull'     --branch main --repository "$RepoName" --repository-type tfsgit --yaml-path .pipelines/pull.yml

az pipelines create --skip-first-run true `
    --name 'AzOps - Validate' --branch main --repository "$RepoName" --repository-type tfsgit --yaml-path .pipelines/validate.yml

# Add build validation policy to validate pull requests
az repos policy build create --blocking true --branch main `
    --build-definition-id (az pipelines show --name 'AzOps - Validate' --query 'id') `
    --display-name 'Validate' --enabled true --queue-on-source-update-only false `
    --repository-id (az repos list --query "[?name=='$RepoName'].id" -o tsv) `
    --manual-queue-only false --valid-duration 0 --path-filter '/root/*'

# Add branch policy to limit merge types to squash only
az repos policy merge-strategy create --blocking true --branch main `
    --repository-id (az repos list --query "[?name=='$RepoName'].id" -o tsv) --enabled true `
    --allow-no-fast-forward false --allow-rebase false --allow-rebase-merge false `
    --allow-squash true

# Add permissions for the Build Service account to the git repository
$AzureDevOpsGlobalAppId = '499b84ac-1321-427f-aa17-267ca6975798'
$AzureReposSecurityNamespaceId = '2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87'
$ProjectId = az devops project list --query "value[?name=='$ProjectName'].id" -o tsv
$RepoId = az repos list --query "[?name=='$RepoName'].id" -o tsv
$QueryStrings = "searchFilter=General&queryMembership=None&api-version=6.0&filtervalue=$ProjectName Build Service ($Organization)"
$Uri = "`"https://vssps.dev.azure.com/$Organization/_apis/identities?$QueryStrings`""
$Subject = az rest --method get --uri $Uri --resource $AzureDevOpsGlobalAppId -o json | ConvertFrom-Json
$Body = @{
    token                = "repov2/$ProjectId/$RepoId"
    merge                = $true
    accessControlEntries = @(
        @{
            # Contribute: 4
            # Force push: 8
            # CreateBranch: 16
            # Contribute to pull requests: 16384
            # Bypass policies when completing pull requests: 32768
            allow      = 4 + 8 + 16 + 16384 + 32768
            deny       = 0
            descriptor = $Subject.value.descriptor
        }
    )
} | ConvertTo-Json -Compress | ConvertTo-Json # Convert to json twice to properly escape characters for Python interpreter
$Uri = "`"https://dev.azure.com/$Organization/_apis/accesscontrolentries/${AzureReposSecurityNamespaceId}?api-version=6.0`""
az rest --method post --uri $Uri --body $Body --resource $AzureDevOpsGlobalAppId -o json

# Add pipeline permissions for all three pipelines to the credentials Variable Groups
$AzureDevOpsGlobalAppId = '499b84ac-1321-427f-aa17-267ca6975798'
$Pipelines = az pipelines list --query "[? contains(name,'AzOps')].{id:id,name:name}" | ConvertFrom-Json
$Body = @(
    @{
        resource  = @{}
        pipelines = @(
            foreach ($pipeline in $Pipelines) {
                @{
                    id         = $pipeline.id
                    authorized = $true
                }
            }
        )
    }
) | ConvertTo-Json -Depth 5 -Compress | ConvertTo-Json # Convert to json twice to properly escape characters for Python interpreter
foreach($groupName in 'credentials','azops') {
  $VariableGroup = az pipelines variable-group list --query "[?name=='$groupName'].{id:id,name:name}" | ConvertFrom-Json
  $Uri = "`"https://dev.azure.com/$Organization/$ProjectName/_apis/pipelines/pipelinepermissions/variablegroup/$($VariableGroup.id)?api-version=6.1-preview.1`""
  az rest --method patch --uri $Uri --body $Body --resource $AzureDevOpsGlobalAppId -o json
}
```

- Your new Project is now ready. Skip down to [Configuration, clean up and triggering the pipelines](#configuration-clean-up-and-triggering-the-pipelines) to get started.

## Configure AzOps via Azure DevOps Portal

- Import the above [AzOps-Accelerator repository](https://github.com/Azure/AzOps-Accelerator.git) to new project.

    1. `Repos` and then `Files`.

        ![Azure-DevOps-repository](./Media/Pipelines/Azure-DevOps-repository.PNG)

    1. Select Import.

        ![Import-Repository](./Media/Pipelines/Import.png)

    1. Provide the Clone URL of the AzOps Accelerator repository and import:
        <https://github.com/Azure/AzOps-Accelerator.git>

        ![Azure-DevOps-repository-URL](./Media/Pipelines/Import-Repository.png)

    1. Set default branch. Go to `Repos` and then `Branches` select `main` and `Set as default branch`

        ![Azure-DevOps-SwitchBranch-URL](./Media/Pipelines/SwitchBranch.png)

    1. Once done it looks something like this (on `main` branch).

        ![Azure-DevOps-repository-2](./Media/Pipelines/Azure-DevOps-repository-2.png)

- Create two new Variable groups by navigating to `Pipelines` then `Library`

  ![Azure-DevOps-Var](./Media/Pipelines/Var.png)

  - Set the first `Variable group name` to `credentials`. This can be altered but the value in the
    `.pipelines\.templates\vars.yml` then need to be updated as well.

  - Add the variables from the `Service Principal` creation to the `credentials Variable group`.

    > If you are running self-hosted build agents in Azure with Managed Identity enabled set the value for `ARM_CLIENT_ID` and `ARM_CLIENT_SECRET` to `null`.

    ```shell
    ARM_CLIENT_ID
    ARM_CLIENT_SECRET
    ARM_SUBSCRIPTION_ID
    ARM_TENANT_ID
    ```

    > Note: Change the variable type for ARM_CLIENT_SECRET to secret.

    ![Library](./Media/Pipelines/Library.png)

  - Set the second `Variable group name` to `azops`. This can be altered but the value in the
    `.pipelines\.templates\vars.yml` then need to be updated as well.

    ```shell
    AZOPS_CUSTOM_SORT_ORDER
    AZOPS_MODULE_VERSION
    ```

    > Note: Set the variable `AZOPS_CUSTOM_SORT_ORDER` value to `false`.

    ![Library](./Media/Pipelines/azopslib.png)

- Configure pipelines: Create three new pipelines (without running them), selecting the existing files in the following order:
  > Note: Make sure to create the pipelines in the correct order, otherwise the pull pipeline will not be triggered by the push pipeline.
  - \.pipelines/push.yml
  - \.pipelines/pull.yml
  - \.pipelines/validate.yml

  > Note: It is advised to set `Pipeline permissions` with `Restrict permission` and only allow each pipeline access to each `Variable group`.


<br/>

**Steps to create pipelines:**

1. Navigate to `Pipelines` and click on `Create pipeline`.

    ![New-Pipeline](./Media/Pipelines/CreatePipeline.png)

1. Select the `Azure Repos Git` option and choose `Existing Azure Pipelines YAML file`.

    ![Azure-repo-git](./Media/Pipelines/Azure-repo-git.PNG)

    ![Existing-Pipeline](./Media/Pipelines/Existing-Pipeline.PNG)

1. Create new pipelines, selecting the existing files

    ![Pull-Push-Pipeline](./Media/Pipelines/Pull-Push-Pipeline.PNG)

- Rename the Pipelines to `AzOps - Push`, `AzOps - Pull` and `AzOps - Validate` respectively
  (in both the YAML file, and within the pipeline after you create it).

  ![Pipelines](./Media/Pipelines/Pipelines.PNG)

- Assign permissions to build service account at repository scope.
  The build service account must have the following permissions on the repository.
  - **Contribute**
  - **Contribute to pull requests**
  - **Create branch**
  - **Force push**

  When using branch policies, also add the build service permission to
  **Bypass policies when completing pull requests** to be able to merge automated pull requests.

  1. Navigate to the project settings, within the Repos section, select Repositories, select the newly created
  repository.

  1. Select the [Project] Build Service ([Organization]) account, and configure the permissions above.

     ![Permission1](./Media/Pipelines/Permission1.PNG)

- Configure branch policies
  In order for the `AzOps - Validate` pipeline to run, set the repository main
  branch to require build verification using most of default settings, but do define a path filter matching
  your state setting, for example: `/root/*`.
  ![Branch-policy-1](./Media/Pipelines/Branch-policy-1.PNG)

- Allow only squash merge types from branches into main.

     ![Build-validation](./Media/Pipelines/Build-validation.PNG)

## Configuration, clean up and triggering the pipelines

- Configuration values can be modified within the `settings.json` file to change the default behavior of AzOps. The settings are documented in [Settings chapter](.\Settings.md)

- Optionally, add the variable `AZOPS_MODULE_VERSION` to the `Variable group` `azops` to pin the version of the AzOps module to be used

- This deployment is configured for Azure Pipelines. It is safe to
  delete the `.github` folder and any Markdown files in the root of the repository

    ![Remove-Github-Folder](./Media/Pipelines/Remove-Github-Folder.PNG)

- Now, we are good to trigger the first push, which will in turn trigger the first pull to fetch the existing
  Azure environment
  ![Pipelines](./Media/Pipelines/Pipelines.PNG)

- Once pull pipeline completes it will look like the screenshot below

  ![Pull](./Media/Pipelines/Pull.PNG)

- This `root` folder contains existing state of Azure environment

- Now, start creating arm templates to deploy more resources as shown in screenshot below

  ![RG](./Media/Pipelines/RG.PNG)
   > Note: Please follow above naming convention for parameter file creation.

- Creating a Pull Request with changes to the `root` folder will trigger a validate pipeline. The validate pipeline will perform a What-If deployment of the changes and post the results as a comment om the pull request

- Merge the Pull Request to trigger the push pipeline and deploy the changes

  ![Pipelines](./Media/Pipelines/Pipelines.PNG)
