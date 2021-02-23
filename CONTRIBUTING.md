# Contributing Guide

The following should be noted when contributing to this project.

## Additional Notes

### Debugging AzOps in VSCode

By default, setting breakpoints on AzOps in VS Code will not work.
This is due to the files being invoked as scriptblock by default, rather than as file, for performance reasons.
To work around this issue, set a configuration setting to disable thisbehavior:

```powershell
Set-PSFConfig AzOps.Import.DoDotSource $true
```

You can make it remember that by registering the setting:

```powershell
Set-PSFConfig AzOps.Import.DoDotSource $true -PassThru | Register-PSFConfig
```
