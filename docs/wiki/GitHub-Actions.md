### In this guide

- [Portal](#portal)
  - [Create the repository](#create-the-repository)
  - [Configure the secrets](#configure-the-secrets)
- [Scripts](#scripts)

---

### Portal

#### Create the repository

Browse to the [AzOps Accelerator](https://github.com/azure/azops), and select *Use this template*

![Create the repository from the template](./Media/Actions/Template-Repository.png)

Select whether the owner will be an organization or user and provide a repository name.

We'd recommended creating the new repository as *private*.

There is no need to include all branches as all latest stable changes reside within the main branch.

![Configure the repository](./Media/Actions/Repository-Configuration.png)

#### Configure the secrets

Navigate to *settings* on the newly created repository, select the *Secrets* section.

Create the following repository secrets:

![Configure the repository secrets](./Media/Actions/Repository-Secrets.png)

Select the *Options* sections, untick *Merge commits* and *Rebase merging*.

![Configure the merge types](./Media/Actions/Merge-Types.png)

---

### Scripts

Create the repository from the pre-defined template

```bash
gh repo create '<Name>' --template azure/azops-accelerator --private --confirm
```

Add the repository secrets

```bash
gh secret set 'ARM_TENANT_ID' -b "<Secret>"
gh secret set 'ARM_SUBSCRIPTION_ID' -b "<Secret>"
gh secret set 'ARM_CLIENT_ID' -b "<Secret>"
gh secret set 'ARM_CLIENT_SECRET' -b "<Secret>"
```

Initiaite the first Pull workflow

```bash
gh api -X POST /repos/:owner/:repo/dispatches -f event_type='Enterprise-Scale Deployment'
```
