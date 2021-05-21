_Coming soon_

### In this guide

- [Project](#project)
- [Repository - Import](#repository-import)
- [Repository - Sync](#repository-sync)
- [Artifacts - Release](#artifacts-release)
- [Workflows]

---

### Project

{Description}

{Image}

### Repository - Import

{Description}

{Image}

### Repository - Sync

#### Add the repository permissions

> This is to allow the Sync pipeline to keep the repository up to date

- Navigate to the repository permissions
- Select the 'Project' Build Service ('Organisation') user account
- Set Allow on the Contribute option

#### Create the pipeline

- Browse to the Azure Pipelines section
- Select `Create Pipeline`
- Select `Azure Repos Git`
- Select the repository
- Select `Existing Azure Pipelines YAML file`
- Select `/.pipelines/sync.yml`
- Select the arrow next to `Run` and `Save`
- Select the three dots on the top right
- Select `Rename/move pipelines`
- Update the name to `Sync` or other desire

#### Run the pipelines

- Run the sync pipeline and validate there aren't any errors
- The sync stage should display `Already up to date.` and `Everything up-to-date` in the logs

### Artifacts - Release

#### Create the feed

- Navigate to the `Azure Artifacts`
- Select `Create Feed`
- Provide a name, this will be used later in the release pipeline
- Select default options
- Select organization scope

#### Add the feed permissions

- Navigate to the created feed
- Add the Example Build Service (lytill) account as a contributor
- Add the AzTest Build Service (lytill) account as a contributor

#### Create the pipeline

- Browse to the Azure Pipelines section
- Select `Create Pipeline`
- Select `Azure Repos Git`
- Select the repository
- Select `Existing Azure Pipelines YAML file`
- Select `/.pipelines/release.yml`
- Select `Variables`
- Select `New variable`
- Add a new variable named `FEED_NAME` with the name of the feeds
- Add the value from the previous section and `Save`
- Select the arrow next to `Run` and `Save`
- Select the three dots on the top right
- Select `Rename/move pipelines`
- Update the name to `Release` or other desire
- Edit the `Release` pipeline
- Select the three dots on the top right
- Select `Triggers`
- Select `Override the YAML continuous integration trigger from here`
- Select `Disable continuous integration`
- Select arrow and `Save`

#### Run the pipeline

- Run the release pipeline to upload the first verrsions of the

### Workflows

Azure Pipelines

```yml
- task: PowerShell@2
  displayName: "Dependencies"
  inputs:
    targetType: "inline"
    script: |
      $credential = New-Object System.Management.Automation.PSCredential("$(System.AccessToken)",(ConvertTo-SecureString -String $(System.AccessToken) -AsPlainText -Force))
      Register-PackageSource -Name 'AzureArtifacts' -ProviderName 'PowerShellGet' -Location https://pkgs.dev.azure.com/{orgName}/_packaging/{feedName}/nuget/v2/ -Credential $credential
      $module = Find-Module -Name AzOps -AllowPrerelease -Repository 'AzureArtifacts' -Credential $credential
      $module.Dependencies | ForEach-Object { Install-Module -Name $_.Name -RequiredVersion $_.MinimumVersion -Repository 'AzureArtifacts' -Credential $credential -Force }
      Install-Module -Name AzOps -AllowPrerelease -Repository 'AzureArtifacts' -Credential $credential -Force
```
