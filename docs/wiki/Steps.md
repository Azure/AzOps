## In this guide

- [Validate](#validate)
- [Push](#push)
- [Pull](#pull)

---

## Validate

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Dependencies**  
  Download and install AzOps (*Pre-release*), Az.Accounts, Az.Billing, Az.Resources and PSFramework modules.

* **Connect**  
  Authenticate the PowerShell session on the runner via Service Principal.

* **Diff**  
  Validate if there have been any changes within Azure Resource Manager and the Git representation of the hierarchy.

* **Validate**  
  Validate the new template changes to Azure Resource Manager
  
* **Results**  
  Post the results from the What-If API into the Pull Request 

## Push

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Dependencies**  
  Download and install AzOps (*Pre-release*), Az.Accounts, Az.Billing, Az.Resources and PSFramework modules.

* **Connect**  
  Authenticate the PowerShell session on the runner via Service Principal.

* **Diff**  
  Validate if there have been any changes within Azure Resource Manager and the Git representation of the hierarchy.

* **Deploy**  
  Push the new template changes to Azure Resource Manager

## Pull

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Configure**  
  Setup the local git command line tools to allow to commit and push changes back to the repository.

* **Checkout**  
  Switch branches from the main branch to a newly created automated branch.

* **Dependencies**  
  Download and install AzOps, Az.Accounts, Az.Billing, Az.Resources and PSFramework modules.

* **Connect**  
  Authenticate the PowerShell session on the runner via Service Principal.

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
