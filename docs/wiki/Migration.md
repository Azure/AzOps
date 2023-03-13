This doc goes through the steps required to migrate from the old container based AzOps version to the new one hosted in this repository. 

> If you prefer to create a new repository for the new version instead of migrating your existing one, just follow the [getting started guide](https://github.com/azure/azops/wiki/github-actions) and decommission the old repository after the new one is up and running. 

***
### 1. Add [settings.json](https://github.com/Azure/AzOps-Accelerator/blob/main/settings.json) file to repository 
This file contains all [configurable settings](https://github.com/azure/azops/wiki/settings) for AzOps. 
These settings were previously exposed as variables directly in the pipelines - ensure any changes that was previously made directly in the pipeline is reflected in settings.json. 

### 2. Inline replace azops-pull.yml / azops-push.yml with the new pull.yml/push.yml pipelines 

### 3. Replace AZURE_CREDENTIALS secret with the following four secrets
```
- ARM_TENANT_ID
- ARM_SUBSCRIPTION_ID
- ARM_CLIENT_ID
- ARM_CLIENT_SECRET
```
> Note that you do not need to create a new service principal
### 4. _(Optional)_ Rename azops/ folder to root/
This will need to be pushed into main without triggering the push pipeline, when you run the next Pull it'll regenerate with the root/ path.

_Only required if you have custom templates that you want to keep in the azops/ folder structure. If rename is not done, the root folder will automatically be created on the first push action run._ 
