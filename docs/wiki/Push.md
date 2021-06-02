### Workflow

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
