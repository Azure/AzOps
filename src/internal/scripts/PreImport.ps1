﻿<#
Add all things you want to run before importing the main function code.

WARNING: ONLY provide paths to files!

After building the module, this file will be completely ignored, adding anything but paths to files ...
- Will not work after publishing
- Could break the build process
#>

$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

# Load the strings used in messages
"$moduleRoot\internal\scripts\Strings.ps1"

# Load the class definitions (must exist before declaring functions)
(Get-ChildItem "$moduleRoot\internal\classes\*.ps1" -ErrorAction Ignore).FullName