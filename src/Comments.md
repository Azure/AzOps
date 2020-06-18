**AzOps**

Status: _Out of Sync_

Description:

_The repository does not contain the latest Azure Resource Manager state, remediation is required before merging of the Pull Request can complete._

Remediation:

You can [re-initialize](https://github.com/Azure/Enterprise-Scale/blob/main/docs/Deploy/discover-environment.md#initialize-existing-environment) your repository to pull latest changes from Azure by invoking GitHub Action. You can monitor the status of the GitHub Action in `Actions` Tab. Upon successful completion, this will create a new `system` branch and Pull Request containing changes with latest configuration. Name of the Pull Request will be `Azure Change Notification`.

- 1. Please merge Pull Request from `system`  branch in to your `main` branch.
- 2. Update you feature branch from  main `git pull origin/main`
- 3. Push your branch to `origin` by running following command `git push`

Upon successful push, GitHub Action workflow should automatically run.

To get started, type the following commands either in `bash` or `powershell` shell. Please replace the placeholders (<...>) with your values:

In a terminal, type the following commands by replacing the placeholders (<...>) with your actual values:

### Github Cli (Does not Require PAT token)

```bash
gh api -X POST repos/<Your GitHub ID>/<Your Repo Name>/dispatches --field event_type=activity-logs
````

### PowerShell

```powershell
$GitHubUserName = "<GH UserName or Github Enterprise Organisation Name>"
$GitHubPAT = "<PAT TOKEN>"
$GitHubRepoName = "<Repo Name>"
$uri = "https://api.github.com/repos/$GitHubUserName/$GitHubRepoName/dispatches"
$params = @{
    Uri = $uri
    Headers = @{
        "Accept" = "application/vnd.github.everest-preview+json"
        "Content-Type" = "application/json"
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $GitHubUserName,$GitHubPAT))))"
        }
    Body = @{
        "event_type" = "activity-logs"
        } | ConvertTo-json
    }
Invoke-RestMethod -Method "POST" @params
```

### Bash

```bash
curl -u "<GH UserName>:<PAT Token>" -H "Accept: application/vnd.github.everest-preview+json"  -H "Content-Type: application/json" https://api.github.com/repos/<Your GitHub ID>/<Your Repo Name>/dispatches --data '{"event_type": "activity-logs"}'
```
