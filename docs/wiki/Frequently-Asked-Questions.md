# AzOps FAQ

This article answers frequently asked questions relating to AzOps.

## In this Section

  - [Subscription or resources not showing up in repository?](#subscription-or-resources-not-showing-up-in-repository)



## Subscription or resources not showing up in your repository?

If subscriptions, resource groups or resources are not showing up in your repository (it affects both pull operations and push deployments of new resources). This can happen because there are invalid characters in the resource path. 

To confirm if this applies to you, check the pipeline logs for any of the following messages:
```powershell
[ConvertTo-AzOpsState] The specified AzOpsState file contains invalid characters (remove any "[" or "]" characters)! <PathToResource> 
```

```powershell
[New-AzOpsScope] Path not found: <PathToResource> 
```
Remove the invalid resource or character and retry the operation.