# AzOps

![GitHub issues by-label](https://img.shields.io/github/issues/azure/azops/enhancement?label=enhancement%20issues)
![GitHub issues by-label](https://img.shields.io/github/issues/azure/azops/bug?label=bug%20issues)
![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/azops)
![GitHub Super-Linter](https://github.com/Azure/AzOps/workflows/AzOps%20-%20Tests/badge.svg)
![GitHub Super-Linter](https://github.com/Azure/AzOps/workflows/Lint%20Code%20Base/badge.svg)

This repository is for active development of the AzOps PowerShell cmdlets.

## Getting started

For tutorials, samples and quick starts, visit the [AzOps Accelerator](https://github.com/azure/azops-accelerator) template repository.

## Dependencies

- [Az.Accounts](https://github.com/azure/azure-powershell)
- [Az.Billing](https://github.com/azure/azure-powershell)
- [Az.Resources](https://github.com/azure/azure-powershell)
- [PSFramework](https://github.com/PowershellFrameworkCollective/psframework)

## Need help?

For introduction guidance, visit the [GitHub Wiki](https://github.com/azure/azops/wiki)  
For reference documentation, visit the [Enterprise-Scale](https://github.com/azure/enterprise-scale)  
For tutorials, samples and quick starts, go to [AzOps Accelerator](https://github.com/azure/azops-accelerator)  
For information on contributing to the module, visit the [Contributing Guide](https://github.com/Azure/azops/wiki/debug)  
For information on migrating to the new version, visit the [Migration Guide](https://github.com/azure/azops/wiki/migration)  
File an issue via [GitHub Issues](https://github.com/azure/azops/issues/new/choose)  

## Output

AzOps is rooted in the principle that everything in Azure is a resource and to operate at-scale, it should be managed declaratively to determine target goal state of the overall platform.

This PowerShell module provides the ability to deploy Resource Templates & Bicep files at all Azure [scope](https://learn.microsoft.com/azure/role-based-access-control/scope-overview) levels. To provide this functionality the multiple scopes within Azure Resource Manager are represented (example below) within Git. Using directories and files, templates can be deployed (Push) at various scopes whilst also exporting (Pull) composite templates from ARM and placing them within the repository.

```bash
root
└── tenant root group (e42bc18f)
    ├── applications (73fded8a)
    │   ├── development (204bf7a2)
    │   │   ├── microsoft.authorization_roleassignments-4f687d42.json
    │   │   ├── microsoft.management_managementgroups-204bf7a2.json
    │   │   └── subscription-1 (fdfda291)
    │   │       ├── microsoft.authorization_policyassignments-securitycenterbuiltin.json
    │   │       └── microsoft.subscription_subscriptions-fdfda291.json
    │   ├── microsoft.authorization_roleassignments-219d3675.json
    │   ├── microsoft.management_managementgroups-73fded8a.json
    │   └── production (75718043)
    │       ├── microsoft.authorization_roleassignments-5bf6a637.json
    │       ├── microsoft.management_managementgroups-75718043.json
    │       └── subscription-2 (ad32efed)
    │           ├── microsoft.authorization_policyassignments-dataprotectionsecuritycenter.json
    │           ├── microsoft.authorization_policyassignments-securitycenterbuiltin.json
    │           └── microsoft.subscription_subscriptions-ad32efed.json
    ├── microsoft.authorization_roleassignments-d18adbf0.json
    ├── microsoft.authorization_roledefinitions-40db802e.json
    ├── microsoft.management_managementgroups-e42bc18f.json
    └── platform (4dc7bd90)
        ├── microsoft.authorization_policydefinitions-3029d7f6.parameters.json
        ├── microsoft.authorization_roleassignments-92ebbfe0.json
        ├── microsoft.management_managementgroups-4dc7bd90.json
        └── subscription-0 (1e045925)
            ├── microsoft.authorization_policyassignments-dataprotectionsecuritycenter.json
            ├── microsoft.authorization_policyassignments-securitycenterbuiltin.json
            ├── microsoft.authorization_roleassignments-3d8b69be.json
            ├── microsoft.subscription_subscriptions-1e045925.json
            └── networks
                └── microsoft.resources_resourcegroups-networks.json
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
