<#
.SYNOPSIS
    PowerShell data file containing configuration settings for PSScriptAnalyzer.
.DESCRIPTION
    PowerShell data file containing configuration settings for PSScriptAnalyzer.
    This file contains PSScriptAnalyzer settings used by PSScriptAnalyzer in ./AzOps/tests/AzOps.PSScriptAnalyzer.Tests.ps1
.EXAMPLE
    None
.INPUTS
    None
.OUTPUTS
    None
#>

@{

    IncludeRules    = @(
        # The following array items control which tests will be included when running PSScriptAnalyzer
        # Toggle comment against each item to to add/remove rules.

        # Line up assignment statements such that the assignment operator are aligned.
        "PSAlignAssignmentStatement",

        # An alias is an alternate name or nickname for a cmdlet or for a command element, such as a function, script, file, or executable file. An implicit alias is also the omission of the 'Get-' prefix for commands with this prefix. But when writing scripts that will potentially need to be maintained over time, either by the original author or another Windows PowerShell scripter, please consider using full cmdlet name instead of alias. Aliases can introduce these problems, readability, understandability and availability.
        "PSAvoidUsingCmdletAliases",

        # This automatic variables is built into PowerShell and readonly.
        "PSAvoidAssignmentToAutomaticVariable",

        # Switch parameter should not default to true.
        "PSAvoidDefaultValueSwitchParameter",

        # Mandatory parameter should not be initialized with a default value in the param block because this value will be ignored.. To fix a violation of this rule, please avoid initializing a value for the mandatory parameter in the param block.
        "PSAvoidDefaultValueForMandatoryParameter",

        # Empty catch blocks are considered poor design decisions because if an error occurs in the try block, this error is simply swallowed and not acted upon. While this does not inherently lead to bad things. It can and this should be avoided if possible. To fix a violation of this rule, using Write-Error or throw statements in catch blocks.
        "PSAvoidUsingEmptyCatchBlock",

        # Checks that global aliases are not used. Global aliases are strongly discouraged as they overwrite desired aliases with name conflicts.
        "PSAvoidGlobalAliases",

        # Checks that global functions and aliases are not used. Global functions are strongly discouraged as they can cause errors across different systems.
        "PSAvoidGlobalFunctions",

        # Checks that global variables are not used. Global variables are strongly discouraged as they can cause errors across different systems.
        "PSAvoidGlobalVars",

        # Invoking non-constant members would cause potential bugs. Please double check the syntax to make sure members invoked are non-constant.
        "PSAvoidInvokingEmptyMembers",

        # Line lengths should be less than the configured maximum
        "PSAvoidLongLines",

        # Setting the HelpMessage attribute to an empty string or null value causes PowerShell interpreter to throw an error while executing the corresponding function.
        "PSAvoidNullOrEmptyHelpMessageAttribute",

        # Do not overwrite the definition of a cmdlet that is included with PowerShell
        "PSAvoidOverwritingBuiltInCmdlets",

        # Readability and clarity should be the goal of any script we expect to maintain over time. When calling a command that takes parameters, where possible consider using name parameters as opposed to positional parameters. To fix a violation of this rule, please use named parameters instead of positional parameters when calling a command.
        "PSAvoidUsingPositionalParameters",

        # Checks for reserved characters in cmdlet names. These characters usually cause a parsing error. Otherwise they will generally cause runtime errors.
        "PSReservedCmdletChar",

        # Checks for reserved parameters in function definitions. If these parameters are defined by the user, an error generally occurs.
        "PSReservedParams",

        # Functions that use ShouldContinue should have a boolean force parameter to allow user to bypass it.
        "PSAvoidShouldContinueWithoutForce",

        # Each line should have no trailing whitespace.
        "PSAvoidTrailingWhitespace",

        # Functions should take in a Credential parameter of type PSCredential (with a Credential transformation attribute defined after it in PowerShell 4.0 or earlier) or set the Password parameter to type SecureString.
        "PSAvoidUsingUsernameAndPasswordParams",

        # The ComputerName parameter of a cmdlet should not be hardcoded as this will expose sensitive information about the system.
        "PSAvoidUsingComputerNameHardcoded",

        # Using ConvertTo-SecureString with plain text will expose secure information.
        "PSAvoidUsingConvertToSecureStringWithPlainText",

        # "ModuleToProcess" is obsolete in the latest PowerShell version. Please update with the latest field "RootModule" in manifest files to avoid PowerShell version inconsistency.
        "PSAvoidUsingDeprecatedManifestFields",

        # The Invoke-Expression cmdlet evaluates or runs a specified string as a command and returns the results of the expression or command. It can be extraordinarily powerful so it is not that you want to never use it but you need to be very careful about using it.  In particular, you are probably on safe ground if the data only comes from the program itself.  If you include any data provided from the user - you need to protect yourself from Code Injection. To fix a violation of this rule, please remove Invoke-Expression from script and find other options instead.
        "PSAvoidUsingInvokeExpression",

        # Password parameters that take in plaintext will expose passwords and compromise the security of your system.
        "PSAvoidUsingPlainTextForPassword",

        # Deprecated. Starting in Windows PowerShell 3.0, these cmdlets have been superseded by CIM cmdlets.
        "PSAvoidUsingWMICmdlet",

        # Avoid using the Write-Host cmdlet. Instead, use Write-Output, Write-Verbose, or Write-Information. Because Write-Host is host-specific, its implementation might vary unpredictably. Also, prior to PowerShell 5.0, Write-Host did not write to a stream, so users cannot suppress it, capture its value, or redirect it.
        "PSAvoidUsingWriteHost",

        # Use commands compatible with the given PowerShell version and operating system
        "PSUseCompatibleCommands",

        # Use script syntax compatible with the given PowerShell versions
        "PSUseCompatibleSyntax",

        # Use types compatible with the given PowerShell version and operating system
        "PSUseCompatibleTypes",

        # Ending a line with an escaped whitepsace character is misleading. A trailing backtick is usually used for line continuation. Users typically don't intend to end a line with escaped whitespace.
        "PSMisleadingBacktick",

        # Some fields of the module manifest (such as ModuleVersion) are required.
        "PSMissingModuleManifestField",

        # Close brace should be on a new line by itself.
        "PSPlaceCloseBrace",

        # Place open braces either on the same line as the preceding expression or on a new line.
        "PSPlaceOpenBrace",

        # Checks that $null is on the left side of any equaltiy comparisons (eq, ne, ceq, cne, ieq, ine). When there is an array on the left side of a null equality comparison, PowerShell will check for a $null IN the array rather than if the array is null. If the two sides of the comaprision are switched this is fixed. Therefore, $null should always be on the left side of equality comparisons just in case.
        "PSPossibleIncorrectComparisonWithNull",

        # '=' or '==' are not comparison operators in the PowerShell language and rarely needed inside conditional statements.
        "PSPossibleIncorrectUsageOfAssignmentOperator",

        # When switching between different languages it is easy to forget that '>' does not mean 'great than' in PowerShell.
        "PSPossibleIncorrectUsageOfRedirectionOperator",

        # Checks that all cmdlets have a help comment. This rule only checks existence. It does not check the content of the comment.
        "PSProvideCommentHelp",

        # Ensure all parameters are used within the same script, scriptblock, or function where they are declared.
        "PSReviewUnusedParameter",

        # Checks that all defined cmdlets use approved verbs. This is in line with PowerShell's best practices.
        "PSUseApprovedVerbs",

        # For a file encoded with a format other than ASCII, ensure BOM is present to ensure that any application consuming this file can interpret it correctly.
        "PSUseBOMForUnicodeEncodedFile",

        # Cmdlet should be called with the mandatory parameters.
        "PSUseCmdletCorrectly",

        # Use cmdlets compatible with the given PowerShell version and edition and operating system
        "PSUseCompatibleCmdlets",

        # Each statement block should have a consistent indenation.
        "PSUseConsistentIndentation",

        # Check for whitespace between keyword and open paren/curly, around assigment operator ('='), around arithmetic operators and after separators (',' and ';')
        "PSUseConsistentWhitespace",

        # For better readability and consistency, use the exact casing of the cmdlet/function/parameter.
        "PSUseCorrectCasing",

        # Ensure declared variables are used elsewhere in the script and not just during assignment.
        "PSUseDeclaredVarsMoreThanAssignments",

        # Use literal initializer, @{}, for creating a hashtable as they are case-insensitive by default
        "PSUseLiteralInitializerForHashtable",

        # The return types of a cmdlet should be declared using the OutputType attribute.
        "PSUseOutputTypeCorrectly",

        # If a command parameter takes its value from the pipeline, the command must use a process block to bind the input objects from the pipeline to that parameter.
        "PSUseProcessBlockForPipelineCommand",

        # For PowerShell 4.0 and earlier, a parameter named Credential with type PSCredential must have a credential transformation attribute defined after the PSCredential type attribute.
        "PSUsePSCredentialType",

        # Checks that if the SupportsShouldProcess is present, the function calls ShouldProcess/ShouldContinue and vice versa. Scripts with one or the other but not both will generally run into an error or unexpected behavior.
        "PSShouldProcess",

        # Functions that have verbs like New, Start, Stop, Set, Reset, Restart that change system state should support 'ShouldProcess'.
        "PSUseShouldProcessForStateChangingFunctions",

        # Commands typically provide Confirm and Whatif parameters to give more control on its execution in an interactive environment. In PowerShell, a command can use a SupportsShouldProcess attribute to provide this capability. Hence, manual addition of these parameters to a command is discouraged. If a commands need Confirm and Whatif parameters, then it should support ShouldProcess.
        "PSUseSupportsShouldProcess",

        # In a module manifest, AliasesToExport, CmdletsToExport, FunctionsToExport and VariablesToExport fields should not use wildcards or $null in their entries. During module auto-discovery, if any of these entries are missing or $null or wildcard, PowerShell does some potentially expensive work to analyze the rest of the module.
        "PSUseToExportFieldsInManifest",

        # If a ScriptBlock is intended to be run as a new RunSpace, variables inside it should use 'Using:' scope modifier, or be initialized within the ScriptBlock.
        "PSUseUsingScopeModifierInNewRunspaces",

        # PowerShell help file needs to use UTF8 Encoding.
        "PSUseUTF8EncodingForHelpFile",

        # Every DSC resource module should contain folder "Examples" with sample configurations for every resource. Sample configurations should have resource name they are demonstrating in the title.
        "PSDSCDscExamplesPresent",

        # Every DSC resource module should contain folder "Tests" with tests for every resource. Test scripts should have resource name they are testing in the file name.
        "PSDSCDscTestsPresent",

        # Set function in DSC class and Set-TargetResource in DSC resource must not return anything. Get function in DSC class must return an instance of the DSC class and Get-TargetResource function in DSC resource must return a hashtable. Test function in DSC class and Get-TargetResource function in DSC resource must return a boolean.
        "PSDSCReturnCorrectTypesForDSCFunctions",

        # The Get/Test/Set TargetResource functions of DSC resource must have the same mandatory parameters.
        "PSDSCUseIdenticalMandatoryParametersForDSC",

        # The Test and Set-TargetResource functions of DSC Resource must have the same parameters.
        "PSDSCUseIdenticalParametersForDSC",

        # DSC Resource must implement Get, Set and Test-TargetResource functions. DSC Class must implement Get, Set and Test functions.
        "PSDSCStandardDSCFunctionsInResource",

        # It is a best practice to emit informative, verbose messages in DSC resource functions. This helps in debugging issues when a DSC configuration is executed.
        "PSDSCUseVerboseMessageInDSCResource"
    )

    SeverityLevels = @(
        # The following array items control which severtity levels will be included when running PSScriptAnalyzer
        # Toggle comment against each item to to add/remove severity levels.

        "Information",
        "Warning",
        "Error"
    )
}
