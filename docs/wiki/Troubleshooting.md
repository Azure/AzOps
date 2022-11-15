### In this guide

- [General](#general)
- [GitHub Actions](#github-actions)
- [Azure Pipelines](#azure-pipelines)
- [Windows](#windows)

## General

To enable debug logging for the AzOps module, please add the following configuration item to the `settings.json` within the repository.

```json
{
    "Version": 1,
    "Static": {
        "PSFramework.Message.Info.Maximum": 9
    }
}
```

## GitHub Actions

[TODO]

To enable debug logging within GitHub Actions workflows, please visit the [Product Documentation](https://docs.github.com/en/actions/managing-workflow-runs/enabling-debug-logging)

---

## Azure Pipelines

To enable debug logging within Azure Pipelines, please visit the [Product Documentation](https://learn.microsoft.com/en-us/azure/devops/pipelines/troubleshooting/review-logs?view=azure-devops).

TF401027: You need the Git 'ForcePush' permission to perform this action
As part of Step 4, you need to either allow the Build Service, or the Contributor group Force Push on the main branch.

The Directory Role Directory Readers is not returned by Get-AzureADDirectoryRole
The Get-AzureADDirectoryRole only returns roles which have at least one assignment, to use the script to make the role assignment you need to have already been to the Azure Portal and assigned the role previously.

Conversion from JSON failed with error: Input string is not a valid number - AzOps Pull Run Container
Ensure that you're using the $escapedServicePrincipalJson variable string from the script at the beginning of this article. If you use an unescaped JSON string then this error will occur.

---

## Windows

Enabling long paths on Windows
The Git clone below and AzOps GitHub Action implementation requires that you enable long paths in Windows. To enable this, execute the following command from a terminal with elevated privileges:

```
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f
```

You will also need to execute the following command line from an elevated terminal:

```
git config --system core.longpaths true
```

Restart your computer to ensure changes take effect.