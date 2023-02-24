# In this guide

- [Introduction](#introduction)
- [Small Azure environment](#smaller-azure-environment-with-less-than-100-subscriptions)
- [Large Azure environment](#larger-azure-environment-with-over-100-subscriptions)
- [Seeing Warning Message](#warning-message)

---

## Introduction

The performance of AzOps **pull operations** can vary greatly depending on several factors, including the specific Azure environment being used, the configuration settings selected, and the number of compute cores available to the pipeline runtime.

The default configuration of AzOps includes a set of settings (`settings.json`) that determine what is pulled, as well as a PowerShell [throttle limit](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.2#-throttlelimit) of 5, which restricts the number of operations that can be performed in parallel.

  > **_NOTE:_** AzOps [2.0.0](https://github.com/Azure/AzOps/releases/tag/2.0.0) introduced changes to improve performance, including increased usage of parallel threads compared to previous versions.

## Smaller Azure environment with less than 100 subscriptions

The default setup and throttle limit have a relatively minor impact on pull performance.

## Larger Azure environment with over 100 subscriptions

As the number of scopes and objects to pull increases, the time required for processing and waiting also increases, which can negatively impact pull performance.However, by using the right conditions and optimization techniques, the performance of the pull operation can be tuned for better and more reliable results. 

- By adjusting the `Core.ThrottleLimit` value in `settings.json`, AzOps can increase or decrease the amount of parallel threads used during processing. It's important to evaluate whether the number of available cores in the runtime environment is appropriate. Increasing the `Core.ThrottleLimit` value results in a higher level of parallelism, which can improve processing performance

  > **_NOTE:_** If you have a large environment and are experiencing crashed pipelines, consider changing the `Core.ThrottleLimit` setting [approximately](https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/) to the number of available CPU cores, or increase compute CPU cores (if using self-hosted runners).

## Warning Message

Are you receiving a warning message about adjusting `AzOps.Core.ThrottleLimit`?

![Warning Message](./Media/AdjustingThrottleLimit.png)

This means that AzOps has detected that the `Core.ThrottleLimit` value is higher than the available compute cores and has automatically adjusted the setting to reduce the risk of execution failure due to crashing.

To address the warning message, consider the following options:

  a) Change the `Core.ThrottleLimit` to 5 or lower

  b) Increase compute cores (if using self-hosted runners)
