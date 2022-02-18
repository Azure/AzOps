# AzOps Resource Deletion

- [Introduction](#Introduction)
- [How to use](#How-to-use)
- [Integration with AzOps Accelerator](#Integration-with-AzOps-Accelerator)


## Introduction

**AzOps Resource Deletion** performs deletion of policyAssignments, policyExemptions and roleAssignments in Azure, based on `AzOps - Pull` generated templates at all Azure scope levels `(Management Group/Subscription/Resource Group)`.
- For any other resource type **deletion is not supported by AzOps at this time**.

When `Invoke-AzOpsPull` runs, it fetches the existing environment. By removing the file representing a policyAssignment, policyExemption or a roleAssignment AzOps removes the corresponding resouce in Azure.

### How to use

Detailed steps:

1. Trigger the pull to fetch the fresh data of existing Azure environment. Navigate to Actions and run `AzOps - Pull`

    ![ResourceDeletion_workflow](./Media/ResourceDeletion/ResourceDeletion_workflow.PNG)
    ![ResourceDeletion_intial_Pull](./Media/ResourceDeletion/ResourceDeletion_intial_Pull.PNG)

2. It's recommended to capture the current stage either from `portal` or via any `script` to validate the behaviour after completion of the deletion.

    ![ResourceDeletion_RBAC_portal](./Media/ResourceDeletion/ResourceDeletion_RBAC_portal.PNG)
    ![ResourceDeletion_azpolicy_portal](./Media/ResourceDeletion/ResourceDeletion_azpolicy_portal.PNG)

3.Browse to the repository and to the `feature branch` and delete the policyAssignments, policyExemptions or roleAssignments file.

![ResourceDeletion_RBAC_File](./Media/ResourceDeletion/ResourceDeletion_RBAC_File.PNG)
![ResourceDeletion_azpolicy_File](./Media/ResourceDeletion/ResourceDeletion_azpolicy_File.PNG)

4. Once file has been deleted from the branch, create pull request from `Feature Branch` to `Main Branch`.

![ResourceDeletion_Pull_Request_creation](./Media/ResourceDeletion/ResourceDeletion_Pull_Request_creation.PNG)
![ResourceDeletion_Pull_Request_status](./Media/ResourceDeletion/ResourceDeletion_Pull_Request_status.PNG)

5. Once Pull Requested has been created, it will trigger the `AzOps - Validate` pipeline to do initial check. Wait for the pipeline to complete.

![ResourceDeletion_azops_validate_pipeline](./Media/ResourceDeletion/ResourceDeletion_azops_validate_pipeline.PNG)

6. Now the `Approver` can review the pull request. It contains detailed information about which file to delete and pull request can be approved based on that.

![ResourceDeletion_azops_validate_pipeline](./Media/ResourceDeletion/ResourceDeletion_Pull_Request_review.PNG)
![ResourceDeletion_azops_validate_pipeline](./Media/ResourceDeletion/ResourceDeletion_Pull_Request_merge.PNG)

7. With the approval, `AzOps - Push` pipeline will get triggered to apply/implement the requested changes.

 ![ResourceDeletion_azops_push_pipeline](./Media/ResourceDeletion/ResourceDeletion_azops_push_pipeline.PNG)

8. Now the changes can be validated via `Portal` or `Script`

![ResourceDeletion_RBAC_portal1](./Media/ResourceDeletion/ResourceDeletion_RBAC_portal1.PNG)
![ResourceDeletion_azpolicy_portal1](./Media/ResourceDeletion/ResourceDeletion_azpolicy_portal1.PNG)


**_Please Note_**
- SPN used for deletion/change action, should have the below scope in its role definition.

    - For Azure Policy Assignment removal
    ```bash
                Microsoft.Authorization/policyAssignments/delete
                                        OR
                Microsoft.Authorization/policyAssignments/*
                                        OR
                Microsoft.Authorization/* OR  * (For everything)
    ```
    - For Azure Policy Exemption removal
    ```bash
                Microsoft.Authorization/policyExemptions/delete
                                        OR
                Microsoft.Authorization/policyExemptions/*
                                        OR
                Microsoft.Authorization/* OR  * (For everything)
    ```
    - For Azure Role Assignment removal
    ```bash
                Microsoft.Authorization/roleAssignments/delete
                                        OR
                Microsoft.Authorization/roleAssignments/*
                                        OR
                Microsoft.Authorization/* OR  * (For everything)
    ```

### Integration with AzOps Accelerator

The [AzOps Accelerator pipelines](https://github.com/azure/azops-accelerator) (including `Git Hub Actions` & `Azure Pipelines`) incorporates the execution of resource deletion.

Conditional logic has been implemented to call `Invoke-AzOpsPush` with required change set in case of resource deletion operation, while existing logic without resource deletion remains same.

![ResourceDeletion_Pipeline_logic](./Media/ResourceDeletion/ResourceDeletion_pipelineupdate.PNG)

### How to Add AzOps Resource Deletion to existing AzOps - Push and Validate pipelines (applicable to implementations created prior to AzOps release v1.6.0)

1. Update the `AzOps - Push` pipeline by copying content from the latest upstream [push.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.pipelines/push.yml) file into your existing file.
2. Update the `AzOps - Validate` pipeline by copying content from the latest upstream [validate.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.pipelines/validate.yml) file into your existing file.
