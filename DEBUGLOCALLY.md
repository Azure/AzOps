# Debugging AzOps

If you're having issues with AzOps in your CI/CD system, it can be helpful to troubleshoot locally. For this guide, we're going to focus on VS Code as the IDE (i'm using a Windows 10 environment).

## Prerequisites

1. [Visual Studio Code](https://code.visualstudio.com/)
1. The [PowerShell Visual Studio Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)
1. JQ (i install JQ from [Choco](https://community.chocolatey.org/packages/jq) using `choco install jq --verbose -y` and then add its directory (C:\ProgramData\chocolatey\lib\jq\tools) to the PATH env variable)

## Getting started

1. Clone the [project](https://github.com/Azure/AzOps) from GitHub and open with Visual Studio Code
1. Run `Dependency.ps1` from the scripts directory to install the dependant PoSH modules`
1. Login with the correct service principal that has Management Group scope access

```powershell
Clear-AzContext
$Credential = Get-Credential
Connect-AzAccount -Credential $Credential -Tenant xxxx-xxx-xxxx-xxxx-xxx -ServicePrincipal
```

4. Open `Debug.ps1` and observe the value for `PSFramework.Message.Info.Maximum` which indicates the level of verbosity used for logging.  This can be changed further into the debugging process.
1. Run `Debug.ps1`
1. Let the process finish, and observe the new file structure in the repository root.  If this completes without error, then the `Pull` operation should operate without issue in your CI/CD system.

## Making a change

Running `Debug.ps1` in the last step leaves us on a [nested prompt](https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.host.pshost.enternestedprompt). We're now able to feed in new Powershell commands at the command prompt to run in the correct context.

In this example, we're going to provide a new ARM template at a specific scope. The Arm template is the [Create New Subscription](https://github.com/Azure/Enterprise-Scale/blob/main/examples/landing-zones/empty-subscription/emptySubscription.json) template from the Enterprise Scale repo, it has had default values provided for each of the parameters. I'm dropping it inside the file structure that was created in the last step, inside the `Sandboxes` directory (`root\myorg (myorg)\myorg-sandboxes (myorg-sandboxes`)).

At the command prompt i'll provide it the json file path (wrapped as a changeset object), and then run the cmdlet to Invoke the AzOps Change process.

```powershell
$ChangeSet = @("M`troot\myorg (myorg)\myorg-sandboxes (myorg-sandboxes)\new-subscription.json")
Invoke-AzOpsChange -ChangeSet $ChangeSet
```

You can then monitor the PowerShell terminal in VS Code to see the Deployment run.
