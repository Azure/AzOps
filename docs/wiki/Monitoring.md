# In this guide

- [Introduction](#introduction)
- [Troubleshooting AzOps](#troubleshooting-azops)
- [Application Insights](#azure-monitor-application-insights)
  - [Enable Application Insights Monitoring](#enable-application-insights-monitoring)

---

## Introduction

The AzOps module has a variety of logs and metrics that it generates during execution.

Depending on the numeric value set for `Message.Info.Maximum` at `settings.json` different levels of verbosity is outputted. In general a lower value like `1` indicates minimum amount of information generated and a value of `9` indicates the highest possible verbosity,  [read more about the different levels](https://psframework.org/documentation/documents/psframework/logging/basics/message-levels.html).

  > **_NOTE:_** Default verbosity level is `3`, runtime performance is negatively affected by increased verbosity.


## Troubleshooting AzOps

During normal operations changes to verbosity levels are not needed and the default is sufficient. However, when troubleshooting and trying to understand the why and the what has happened it is advised to increase the verbosity to at least `5` or `8`, going all the way up to `9` makes the module very noisy and the amount of events emitted are high
[read more](https://github.com/azure/azops/wiki/troubleshooting).

## Azure Monitor Application Insights

By design the module emits logs to console during execution, in addition to that the module can emit logs to Azure Monitor Application Insights.

AzOps utilizes `TrackTrace` to create a "breadcrumb trail" in Application Insights [view log traces and events coded into the application](https://learn.microsoft.com/en-us/azure/azure-monitor/app/transaction-search-and-diagnostics?tabs=transaction-search), warnings and errors are emitted as `TrackException` for diagnosis and each message generates a `TrackEvent`. In addition to that certain metrics are emitted as `TrackMetric` like `AzOpsPush Time` and `AzOpsPull Time` in seconds.

![Transaction search](./Media/Monitoring/transactionsearch.png)

This can be useful to track performance, key metrics, and exceptions over time.

It is also helpful when you are running the module with several parallel threads `Core.ThrottleLimit` > `1` due to that console output does not work well when running in parallel. By emitting information to Azure Monitor Application Insights this can be overcome without adjusting the `Core.ThrottleLimit`.

### Enable Application Insights Monitoring

1. [Create a Application Insights resource](https://learn.microsoft.com/en-us/azure/azure-monitor/app/create-workspace-resource#create-a-workspace-based-resource).
1. Add a secret named `APPLICATIONINSIGHTS_CONNECTIONSTRING` *(in GitHub or Azure Pipelines)* and enter the connection string for you Application Insights resource, [find your connection string](https://learn.microsoft.com/en-us/azure/azure-monitor/app/sdk-connection-string?tabs=dotnet5#find-your-connection-string).
    > Note: Create the `APPLICATIONINSIGHTS_CONNECTIONSTRING` secret in the same location where you already have `ARM_TENANT_ID`, if you are using Azure Pipelines remember to set the variable type to `secret`.

    > Note: AzOps utilizes the connection string as a secret to authenticate, this requires that local authentication is enabled on the Application Insights resource *(this is due to high performance impact of Application Insights Microsoft Entra ID-based authentication)*.

    > Note: AzOps emits each log event immediately as it happens to ensure messages are not lost. This means each event generates a service call to Application Insights that needs to be authenticated, no batching or schedule is used.
1. Set the `Core.ApplicationInsights` value in `settings.json` to `true`, AzOps will emit logs to both console and designated  Azure Monitor Application Insights.

**_Please Note: For this to work with GitHub in the manner intended (applicable to implementations created prior to AzOps release v2.5.0)_**

Ensure the `Credentials` section is up-to-date exists in your [pull.yml,
push.yml, redeploy.yml, validate.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.github/workflows) files.
```bash
env:
  #
  # Credentials
  #

  APPLICATIONINSIGHTS_CONNECTIONSTRING: ${{ secrets.APPLICATIONINSIGHTS_CONNECTIONSTRING }}
```