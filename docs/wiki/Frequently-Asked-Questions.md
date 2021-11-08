# AzOps FAQ

This article answers frequently asked questions relating to AzOps.

## In this Section

  - [Subscriptions or resources not showing up in repository?](#subscriptions-or-resources-not-showing-up-in-repository)



## Subscriptions or resources not showing up in your repository?

If there are invalid characters in the resource path, discovery of subscriptions, resource groups or resources will fail during push or pull operations.

To confirm if this applies to you, check the pipeline logs for any of the following messages:
```powershell
[ConvertTo-AzOpsState] The specified AzOpsState file contains invalid characters (remove any "[" or "]" characters)! <PathToResource> 
```

```powershell
[New-AzOpsScope] Path not found: <PathToResource> 
```
Remove the invalid resource or character and retry the operation.
