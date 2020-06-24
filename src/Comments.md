## AzOps

_The repository does not contain the latest Azure Resource Manager state, remediation is required before merging of the Pull Request can complete._

### Remediation:

[Re-initialization](https://github.com/Azure/Enterprise-Scale/blob/main/docs/Deploy/discover-environment.md#initialize-existing-environment) of the repository is required to pull the latest changes from Azure by manually invoking the GitHub Action.

Upon successful completion, the action will create a new `system` branch and a new `Azure Change Notification` pull request containing the latest configuration.

- Merge the new pull request from `system` branch into `main` branch

- Update the feature branch from `main` branch - `git pull origin/main`

- Push the feature branch to origin - `git push`

### Steps (Initialize):

To get started, select one of the following options, either `github-cli`, `bash` or `powershell` and enter the following commands in and replace the placeholders (<...>) with your values.

Please note, the `bash` and `powershell` commands will require a GitHub Personal Access Token.

#### GitHub CLI 

```bash
gh api -X POST repos/<Organisation>/<Repository>/dispatches --field event_type='GitHub CLI'
```

#### Bash

```bash
curl -u "<Username>:<Token>" -H "Content-Type: application/json" --url "https://api.github.com/repos/<Organisation>/<Repository>/dispatches" --data '{"event_type": "Bash"}'
```

#### PowerShell

```powershell
$params = @{
    Method  = "Post"
    Uri     = ("https://api.github.com/repos/" + "<Organisation>/<Repository>" + "/dispatches")
    Headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "<Username>", "<Token>"))))"
    }
    Body    = @{
        "event_type" = "PowerShell"
    } | ConvertTo-json
}
Invoke-RestMethod @params
```
