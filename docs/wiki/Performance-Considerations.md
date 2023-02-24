# In this guide

- [Introduction](#introduction)
- [Small Azure environment](#small-azure-environment-to-pull-100-subscriptions)
- [Large Azure environment](#large-azure-environment-to-pull-more-then-100-subscriptions)
- [Seeing Warning Message](#warning-message)

---

## Introduction

AzOps **pull performance** can differ **significantly** depending on Azure environment, configuration settings and compute cores available to runtime.

Default setup of AzOps results in a certain set of settings (`settings.json`) affecting what to pull and a PowerShell [throttle limit](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.2#-throttlelimit) of 5.

**_NOTE:_** In AzOps 2.0.0 changes where introduced to improve performance that makes greater use of parallel threads then before.

## Small Azure environment to pull 100 subscriptions

The default setup and throttle limit is of less impact to the pull performance.

## Large Azure environment to pull more then 100 subscriptions

When the number of scopes and objects to pull increase the time spent processing and waiting increases. As this happens the pull performance can be tuned to perform better when given the right conditions.

- Adjusting the `Core.ThrottleLimit` value in `settings.json` tells AzOps to increase or decrease the amount of parallel threads. Evaluate if the cores available to AzOps in runtime is appropriate. A higher value increases the level or parallel threads for processing.
- - **_NOTE:_** `Core.ThrottleLimit` parameter should be set [approximately](https://devblogs.microsoft.com/powershell/powershell-foreach-object-parallel-feature/) to the number of available cores.

## Warning Message

Are you seeing a warning message `Adjusting AzOps.Core.ThrottleLimit`:

![Warning Message](./Media/AdjustingThrottleLimit.png)

This means AzOps detected that the `Core.ThrottleLimit` value is higher than available compute cores and overrides the declared setting to reduce risk of execution failure due to crashing.

To alleviate the warning consider:

- A) Change the `Core.ThrottleLimit`

- B) Increase compute cores