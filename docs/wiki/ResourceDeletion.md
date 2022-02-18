# AzOps Resource Deletion

- [Introduction](#Introduction)
- [Integration with AzOps Accelerator](#Integration-with-AzOps-Accelerator)

## Introduction

**AzOps Resource Deletion** performs deletion of policyAssignments, policyExemptions and roleAssignments in Azure, based on `AzOps - Pull` generated templates at all Azure scope levels `(Management Group/Subscription/Resource Group)`.

- For any other resource type **deletion** is **not** supported by AzOps at this time.

By removing a AzOps generated file representing an policyAssignment, policyExemption or a roleAssignment AzOps removes the corresponding resource in Azure.

**_Please Note_**

- SPN used for deletion/change action, requires the below actions in its role definition.

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

## Integration with AzOps Accelerator

The [AzOps Accelerator pipelines](https://github.com/azure/azops-accelerator) (including `Git Hub Actions` & `Azure Pipelines`) incorporates the execution of resource deletion.

Conditional logic has been implemented to call `Invoke-AzOpsPush` with required change set in case of resource deletion operation, while existing logic without resource deletion remains same.

![ResourceDeletion_Pipeline_logic](./Media/ResourceDeletion/ResourceDeletion_pipelineupdate.PNG)

## How to Add AzOps Resource Deletion to existing AzOps - Push and Validate pipelines (applicable to implementations created prior to AzOps release v1.6.0)

1. Update the `AzOps - Push` pipeline by copying content from the latest upstream [push.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.pipelines/push.yml) file into your existing file.
2. Update the `AzOps - Validate` pipeline by copying content from the latest upstream [validate.yml](https://github.com/Azure/AzOps-Accelerator/blob/main/.pipelines/validate.yml) file into your existing file.
