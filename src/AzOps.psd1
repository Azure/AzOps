@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'AzOps.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.4'

    # ID used to uniquely identify this module
    GUID              = '4336cc9b-48f8-4b0e-9629-fd1245e848d9'

    # Author of this module
    Author            = 'Customer Architecture and Engineering'

    # Company or vendor of this module
    CompanyName       = 'Microsoft'

    # Copyright statement for this module
    Copyright         = '(c) Microsoft. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Opinionated CI/CD for Azure.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing
    # this module
    RequiredModules   = @(
        @{ ModuleName = 'PSFramework'; ModuleVersion = '1.5.172' }
        @{ ModuleName = "Az.Accounts"; ModuleVersion = "2.2.5" }
        @{ ModuleName = "Az.Billing"; ModuleVersion = "2.0.0" }
        @{ ModuleName = "Az.Resources"; ModuleVersion = "3.2.1" }
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @('bin\AzOps.dll')

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @('xml\AzOps.Types.ps1xml')

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @('xml\AzOps.Format.ps1xml')

    # Functions to export from this module
    FunctionsToExport = @(
        'Initialize-AzOpsEnvironment'
        'Initialize-AzOpsRepository'
    )

    # Cmdlets to export from this module
    # CmdletsToExport = ''

    # Variables to export from this module
    # VariablesToExport = ''

    # Aliases to export from this module
    # AliasesToExport = ''

    # List of all modules packaged with this module
    ModuleList        = @()

    # List of all files packaged with this module
    FileList          = @()

    # Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        #Support for PowerShellGet galleries.
        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease tag applied to this module.
            Prerelease = '-alpha'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}