# Custom Jq Templates

- [Introduction](#introduction)
- [Logic](#logic)
  - [Template Folder and filename](#template-folder-and-filename)

---

## Introduction

As a part of **AzOps Pull**, information retrieved from Azure is converted into files. This is performed at processing with [jq](https://stedolan.github.io/jq/) which applies filters based on templates and re-structures information.

For scenarios where you need to customize the information filtered or its structure, AzOps supports the use of *bring your own templates* by configuring two settings: `Core.SkipCustomJqTemplate` and `Core.CustomJqTemplatePath`.

The setting `Core.SkipCustomJqTemplate` represents the flag to enable (`$false`) or disable (`$true`) the capability and `Core.CustomJqTemplatePath` is the path to the folder location of your custom templates (default's to `.customtemplates`).

## Logic

What happens? when the following is set: `"Core.SkipCustomJqTemplate": true` and `"Core.CustomJqTemplatePath": ".customtemplates"`.

For retrieved resources, AzOps will look for a matching template file in the custom location. If no match is found AzOps falls back to [built-in templates](https://github.com/Azure/AzOps/tree/main/src/data/template).

### Template Folder and filename

AzOps performs transformation of pulled information in three high level steps.

1. Removal templates (*templates specifying information to be filtered away*)
    * Look for folder matching `providerNamespace` and a file matching `resourceType`.jq
    * If no match found default to `generic.jq` at given template folder root

2. Generating Template Parameter (*treat policy definitions with json escaping*)
    * Look for folder matching `providerNamespace` and a file matching `resourceTypeName`.parameters.jq
    * If no match found default to `template.parameters.jq` at given template folder root

3. Generating Template
    * Look for folder matching `providerNamespace` and a file matching `resourceTypeName`.template.jq
    * If no match found default to `template.jq` at given template folder root

Example of custom templates for `policyExemptions`, would result in `policyExemptions` resources being transformed with custom templates (according to step 1 and 3 above) and all other resources being transformed with built-in:
```bash
.customtemplates
└── Microsoft.Authorization
    ├── policyExemptions.template.jq
    └── policyExemptions.jq
```
Example of built-in base templates:
```bash
.built-in
├── Microsoft.Network
│   └── virtualnetworks.jq
├── generic.jq
├── template.jq
├── template.parameters.jq
└── templateChildResource.jq
```