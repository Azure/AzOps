## In this guide

- [Introduction](#introduction)
- [Discovery](#discovery)
- [Deployment](#deployment)
- [Goal State](#goal-state)
- [Operationalize](#operationalize)

---

AzOps is rooted in the principle that **Everything in Azure is a resource** and to operate at-scale, it should be managed declaratively to **determine target goal state** of the overall platform.

In that spirit, the AzOps implementation has the following three tenets:

![Overview](./Media/Implementation-Scope.png)

### Introduction

Provide Git repository for Azure platform configuration.

Git -> Clone or Git -> Fork (preferred) metaphor references to the fact that this repo will provide everything that must be true for Enterprise-Scale - that customers can leverage as-is in their own environment.

### Discovery

Before starting the Enterprise-Scale journey, it is important for customers to discover existing configuration in Azure that can serve as platform baseline. Consequence of not discovering existing environment will be no reference point to rollback or roll-forward after deployment.
Discovery is also important for organizations, who are starting their DevOps and Infrastructure-as-code (IaC) journey, as this can provide a crucial on-ramp path to allow transitioning without starting all-over.

For the purpose of discovery, following resources are considered within the scope of overall Azure platform. This will initialize empty Git repo with current configuration to baseline configuration encompassing following:

- Management Group hierarchy and Subscription organization
  - ResourceTypes:
    - *Microsoft.Management/managementGroups*
    - *Microsoft.Management/managementGroups/subscriptions*
    - *Microsoft.Subscription/subscriptions*
- Policy Definition, Policy Assignment and Policy Exemption for Governance
  - ResourceTypes:
    - *Microsoft.Authorization/policyDefinitions*
    - *Microsoft.Authorization/policyExemptions*
    - *Microsoft.Authorization/policySetDefinitions*
    - *Microsoft.Authorization/policyAssignments*
- Role Definition and Role Assignment
  - ResourceTypes:
    - *Microsoft.Authorization/roleDefinitions*
    - *Microsoft.Authorization/roleAssignments*

We will default to platform schema to represent these configurations in Git. This means calling Azure APIs using PowerShell.

### Deployment

IaC repo will have 100s if not 1000s of configuration artifacts tracked and version controlled. Platform developers will be modifying a very small subset of these artifacts on an on-going basis via pull request. As Git represents the source of the truth and change, we will leverage Git to determine differential changes in each pull request and trigger subsequent deployment actions in Azure only for the artifacts that are changed instead of triggering a full deployment of all artifacts.

#### Definition of Done

- Discover the current Azure environment "as-is" and have an entire Azure platform baseline stored inside Git repo.
- Deploy templates to Azure environment using pipeline by committing templates at appropriate scope without providing deployment scripts.
- Perform platform operations required for Enterprise-Scale but not yet supported inside ARM e.g. Resource Provider Registration, Azure AD Graph Operations, etc. These operations should be handled via pipeline in the interim.

### Goal State

Provide tenant-level ARM template to build Landing Zones using Enterprise-Scale guidelines.

We will enable security, logging, networking, and any other plumbing needed for landing zones (i.e. Subscription) **autonomously** by the way of policy enforcement. We will bootstrap the Azure environment with an ARM template to create the necessary structure for management and networking to declare desired goal state.

File -> New -> Landing Zones (i.e. Subscription) process is ARM orchestrating the following:

- Subscription creation
- Subscription move under the target management structure
- Configuring Subscription to desired state by policy enforcement - autonomously.

To get started, follow the [**User Guide**](https://github.com/Azure/Enterprise-Scale/wiki/Deploying-Enterprise-Scale) that describes how the Enterprise-Scale reference implementations can be deployed at the tenant ("/") root scope. The [reference implementations](https://github.com/azure/enterprise-scale#deploying-enterprise-scale-architecture-in-your-own-environment) provide everything that is necessary in [Implementation Guide](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/implementation-guidelines), and will have the following sequence:

- Create (1) Management Group hierarchy and (2) Subscription organization structure in (Platform + N) fashion where N represents the number of landing zones.
- Create Policies (deployIfNotExists) assigned to (2) Management Groups and (3) Subscription scope to govern and deploy necessary resources, enabling platform autonomy as new landing zones (Subscriptions) are being created by application teams
- Create (3) Policy and Role Assignment to govern and delegate access to resources.

It is important to note that one of the design principles of the Enterprise-Scale is "Policy Driven Governance" and that all the necessary resources leading to the creation of a Landing Zone are deployed using policy. For example, Deploying Key Vault to store platform level secret in management Subscription. Instead of scripting the template deployment to deploy Key Vault, Enterprise-Scale based reference implementation will have a policy definition that deploys the Key Vault in a prescribed manner and policy assignment at management Subscription scope. The benefits of the policy-driven approach are manyfold but the most significant are:

- Platform can provide orchestration capability to bring target resources (in this case Subscription) to desired goal state.
- Continuous conformance to ensure all platform level resources are compliant. As platform is aware of the goal state, platform can assist by monitoring and remediating the resources throughout the life cycle of the resource.
- Platform enables autonomy regardless of the customer's scale point.

#### Definition of Done

- Invoke ARM Template using PowerShell/CLI for tenant-level deployment to create Landing Zone in Azure environment.
- End to end ARM template must allow flexibility to create requisite Management Group and Subscription hierarchy to organize Landing Zones.
- Template must allow declaring goal state at Tenant, Management Group and Subscriptions scope using policies.
- "Export" Azure configuration in a manner that can be consumed and "imported" back into platform.

### Operationalize

In production environment, changes are bound to happen. Ideally these changes are made in a structured way, using the principles of Infrastructure-as-code (IaC): A change would be made by adding or updating a resource definition in an Azure DevOps or Github repository and relying on an automated test and release process to effectuate the change. This gives the IT department a fully transparent change history and full roll-back and roll-forward capabilities.

However, manual changes (made for example using the Azure portal) may be unavoidable due to urgent operational demands. This leads to 'Configuration Drift', where the environment as described in source control no longer reflects the actual state of the Azure resources. To deal with this situation, Enterprise-Scale envisions not only a control mechanism to push changes in the IaC source to the Azure environment, but also to pull changes made outside IaC back into source control. By having that feedback loop in place, we can ensure that:

- The environment described in source control always reflects the actual state of the Azure Subscriptions.
- Changes made manually are not inadvertently rolled back by the next automated deployment of a resource

#### Definition of Done

- Changes made OOB (only for Platform resources) enlisted in Section #1 are tracked in Git.
- Configuration Drifts should surface just like any other pull request for repo owners to determine based on repo level policy whether to roll-back or roll-forward changes - interactively (with human intervention) or automatically.

### Contribution & Implementation Quick Start Guide

- [Contribution to AzOps](../wiki/AzOps-Contribution.md)
- [GitHub Actions](../wiki/GitHub-Actions.md)
- [Azure Pipelines](../wiki/Azure-Pipelines.md)
