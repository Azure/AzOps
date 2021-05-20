Overview of the process which the Push workflow operates

---

### Workflow

### Pre

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Dependencies**  
  Download and install AzOps (*Pre-release*), Az.Accounts, Az.Billing, Az.Resources and PSFramework modules.

* **Connect**  
  Authenticate the PowerShell session on the runner via Service Principal.

* **Initialize**  
  Generate a local file system structure of the Azure Resource Manager hierarchy within the runner.

* **Issue**  
  If changes are detected within the Git Diff then halt the workflow and write warning message to Pull Request.

### Push

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

### Post

* **Checkout**  
  This stage checkouts out the repository source code from the Source Control Platform to the CI/CD runner.

* **Configure**  
  Setup the local git command line tools to allow to commit and push changes back to the repository.

* **Switch**  
  Switch branches from the main branch to a newly created automated branch.

* **Dependencies**  
  Download and install AzOps (*Pre-release*), Az.Accounts, Az.Billing, Az.Resources and PSFramework modules.

* **Connect**  
  Authenticate the PowerShell session on the runner via Service Principal.

* **Initialize**  
  Generate a local file system structure of the Azure Resource Manager hierarchy within the runner.

* **Add**  
  If the previous step is true, add the file changes into the index ready for commit.

* **Commit**  
  Make a note of the changes within the index for the git log.

* **Push**  
  Push the newly committed changes from the local automated branch to a new remote automated branch.

* **Merge**  
  Create a pull request from the remote automated branch and merge it straight into main if permitted.

---

### Settings

**Strict Mode**  
Enable strict mode when pre consistency checking is required on the repository. When disabled the pre steps will be skipped.

**Auto Merge**  
When auto merge is enabled, after the deployment is completed, the new state will be pushed to the head branch and the proposed pull request will be merged directly into the base branch.
