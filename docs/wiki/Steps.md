## In this guide

- [Validate](#validate)
- [Push](#push)
- [Pull](#pull)

---

### Validate

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Get Latest AzOps version** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS NOT set  
  Get the latest AzOps version from PowerShell Gallery and set the variable `AZOPS_MODULE_VERSION` to the version number.

* **Cache AzOps module** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS set  
  Search cache for the AzOps module with the version number set in the variable `AZOPS_MODULE_VERSION` and restore that.

* **Dependencies** *(from sharedSteps template/action)*  
  *Condition*: Only runs if AzOps module was not restored from cache  
  Download and install AzOps and its dependencies (Az.Accounts, Az.Billing, Az.Resources and PSFramework) from PowerShell gallery.

* **Connect** *(from sharedSteps template/action)*  
  Authenticate the PowerShell session on the runner via Service Principal or Managed Identity.  

* **Diff** *(from validate-deploy template/action)*  
  Validate if there have been any changes within Azure Resource Manager and the Git representation of the hierarchy.

* **Custom Sorting** *(from validate-deploy template/action)*  
  *Condition*: Only runs if variable `AZOPS_CUSTOM_SORT_ORDER` is `true`  
  Import all files from **Diff** step and check for a `.order` file in the same directory.  
  Rearrange files in the order specified in the `.order` file to be deployed before other files in the same directory.

* **Validate** *(from validate-deploy template/action)*  
  Push the new template changes to Azure Resource Manager
  
* **Results**  
  Post the results from the What-If API into the Pull Request

### Push

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Get Latest AzOps version** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS NOT set  
  Get the latest AzOps version from PowerShell Gallery and set the variable `AZOPS_MODULE_VERSION` to the version number.

* **Cache AzOps module** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS set  
  Search cache for the AzOps module with the version number set in the variable `AZOPS_MODULE_VERSION` and restore that.

* **Dependencies** *(from sharedSteps template/action)*  
  *Condition*: Only runs if AzOps module was not restored from cache  
  Download and install AzOps and its dependencies (Az.Accounts, Az.Billing, Az.Resources and PSFramework) from PowerShell gallery.

* **Connect** *(from sharedSteps template/action)*  
  Authenticate the PowerShell session on the runner via Service Principal or Managed Identity.

* **Diff** *(from validate-deploy template/action)*  
  Validate if there have been any changes within Azure Resource Manager and the Git representation of the hierarchy.

* **Custom Sorting** *(from validate-deploy template/action)*  
  *Condition*: Only runs if variable `AZOPS_CUSTOM_SORT_ORDER` is `true`  
  Import all files from **Diff** step and check for a `.order` file in the same directory.  
  Rearrange files in the order specified in the `.order` file to be deployed before other files in the same directory.

* **Deploy** *(from validate-deploy template/action)*  
  Push the new template changes to Azure Resource Manager

### Pull

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Get Latest AzOps version** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS NOT set  
  Get the latest AzOps version from PowerShell Gallery and set the variable `AZOPS_MODULE_VERSION` to the version number.

* **Cache AzOps module** *(from sharedSteps template/action)*  
  *Condition*: Only runs if variable `AZOPS_MODULE_VERSION` IS set  
  Search cache for the AzOps module with the version number set in the variable `AZOPS_MODULE_VERSION` and restore that.

* **Dependencies** *(from sharedSteps template/action)*  
  *Condition*: Only runs if AzOps module was not restored from cache  
  Download and install AzOps and its dependencies (Az.Accounts, Az.Billing, Az.Resources and PSFramework) from PowerShell gallery.

* **Connect** *(from sharedSteps template/action)*  
  Authenticate the PowerShell session on the runner via Service Principal or Managed Identity.

* **Configure**  
  Setup the local git command-line tools to allow to commit and push changes back to the repository.

* **Checkout**  
  Switch branches from the main branch to a newly created automated branch.

* **Initialize**  
  Generate a local file system structure of the Azure Resource Manager hierarchy within the runner.

* **Status**  
  Validate if there have been any changes within Azure Resource Manager and the Git representation of the hierarchy.

* **Add**  
  If the previous step is true, add the file changes into the index ready for commit.

* **Commit**  
  Make a note of the changes within the index for the git log.

* **Push**  
  Push the newly committed changes from the local automated branch to a new remote automated branch.

* **Merge**  
  Create a pull request from the remote automated branch and merge it straight into main if permitted.
