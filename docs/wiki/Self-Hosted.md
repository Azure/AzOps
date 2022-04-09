# Self-hosted agents/runners

The AzOps pipelines/actions are running on Microsoft-hosted agents or GitHub Actions hosted virtual environments by default. Depending on your organizations security requirements you might want to use self-hosted agents/runners instead. AzOps have full support for the use of self-hosted agents/runners and this article outlines the requirements needed.

For more information about using GitHub Actions self-hosted runners see, [About self-hosted runners](https://docs.github.com/actions/hosting-your-own-runners/about-self-hosted-runners).
For more information about using Azure DevOps self-hosted agents see, [Azure Pipelines agents](https://docs.microsoft.com/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser).

## Virtual Machine Scale Sets (VMSS)

Virtual Machine Scale Sets are optimal for hosting your self-hosted agents/runners. They are easy to create and manage and will automatically scale as resource demand changes. To learn more about Virtual Machine Scale Sets see, [Virtual Machine Scale Sets documentation](https://docs.microsoft.com/azure/virtual-machine-scale-sets/).

## Image

To setup a VMSS for your self-hosted agents/runners you need an image with all the required software installed. The pipelines and actions provided in the [AzOps-Accelerator](https://github.com/Azure/AzOps-Accelerator) repository are using the GitHub Actions Virtual Environments [`ubuntu-20.04`](https://github.com/actions/virtual-environments/blob/main/images/linux/Ubuntu2004-Readme.md) image by default. The images includes multiple tools and software including all AzOps requirements.

### Build an image using GitHub Actions Virtual Environments

If you want to use the same image as the hosted environments for your self-hosted agents/runners you can build an image following the guides in the [GitHub Actions Virtual Environments](https://github.com/actions/virtual-environments).

### Building your own custom image

If you want to build your own custom lightweight image the following software is required for AzOps to function properly.

#### Required software

AzOps have a couple of dependencies that are required to function properly. When building your custom image, make sure that the following tools are included in the image:

| Software | Recommended minimum version |
|:--|--|
| `jq` | `1.6` |
| `Git` | `2.35.1` |
| `Azure CLI` | `2.34.1` |
| `PowerShell` | `7.2.2` |
| `Bicep` | `v0.5.6` |
| `Github CLI` | `2.7.0` |

> NOTE: `Bicep` is only required if you plan to deploy [Bicep](https://github.com/Azure/bicep) templates using AzOps.

##### PowerShell Modules

AzOps depends on some of the `Az` modules and `PSFramework`, these modules will be installed with `AzOps` during pipeline/action run and are not required to include in your image. But if you want to make your pipelines/actions as fast as possible the modules can be included in your image.

| Module | Required version |
|:--|--|
| `Az.Accounts` | `2.7.3` |
| `Az.Billing` | `2.0.0` |
| `Az.Resources` | `5.4.0` |
| `PSFramework` | `1.6.214` |

##### Azure CLI Extensions

AzOps are using the `az repos` command group which is a part of the `azure-devops` extension to manage pull requests. The extension should be included in the image if running AzOps on Azure DevOps.

| Extension | Required version |
|:--|--|
| `azure-devops` | `0.25.0` |
