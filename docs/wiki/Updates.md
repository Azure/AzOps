## Overview

This Accelerator has been constructed whereby user generated repositories are created from a template design. This means at the point in time when the downstream repository is created, it is up to date however as time progresses there is the possibility that the downstream repository 
doesn't maintain the latest workflow files. Due to on-going development of this project (AzOps) there are times where it's recommended that the downstream workflows / pipelines are updated. We aren't planning to alter the Actions / Pipelines files too frequently however manually copying the contents isn't the perfect solution.

To provide the ability to update Actions / Pipelines on demand we created a solution 'Patch', this will allow users to periodically check the upstream repository (azure/azops) for any changes to the SCM folders and if so copy them changes downstream by creating a new temporary branch and opening a Pull Request for the user to review the changes.

## Prerequisites

Due to permission limitations on the built-in GitHub Token which Git authenticates with it's not possible to push any changes to the `.github/` directory. This means that the Patch workflow requires a manually created [Personal Access Token](https://github.com/settings/tokens) to be provides as a Repository Secrets with the `workflow` permissions set.

<Image>

## GitHub Actions

[Source](https://github.com/azure/azops-accelerator/blob/main/.github/workflows/update.yml)

## Azure Pipelines

[Source](https://github.com/azure/azops-accelerator/blob/main/.pipelines/update.yml)
