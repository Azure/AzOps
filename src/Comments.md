**AzOps**

Status: _Out of Sync_

Description:

_The repository does not contain the latest Azure Resource Manager state, remediation is required before merging of the Pull Request can complete._

Remediation:

- Switch branch

    ```git checkout master```
    ```git checkout -b state```

- Import & execute AzOps cmdlets

    ```Import-Module ./src/AzOps.psd1 -Force```
    ```Initialize-AzOpsRepository -SkipResourceGroup```

- Commit and push updated state

    ```git add azops/```
    ```git status```
    ```git commit -m 'Update azops/'```
    ```git push origin state```

- Create new pull request

- (Admin) Merge pull request

- Re-run status checks
