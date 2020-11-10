<#
.SYNOPSIS
    The cmdlet verifies that required variables are set for the AzOps functions and modules
.DESCRIPTION
    The cmdlet verifies that required variables are set for the AzOps functions and modules
.EXAMPLE
    C:\PS> Test-AzOpsVariables
.EXAMPLE
    C:\PS> Test-AzOpsVariables -VariablesToCheck 'AzOpsState'
.EXAMPLE
    C:\PS> Test-AzOpsVariables -VariablesToCheck 'AzOpsState', 'AzOpsAzManagementGroup', 'AzOpsSubscriptions'
.PARAMETER VariablesToCheck
    Specifies the variable(s) to check. Default value: 'AzOpsState', 'AzOpsAzManagementGroup', 'AzOpsSubscriptions'
.INPUTS
    None
.OUTPUTS
    None
#>
function Test-AzOpsVariables {

    [CmdletBinding()]
    [OutputType([bool])]
    param (
        # Variables to verify
        [Parameter(Mandatory = $false)]
        [String[]]$VariablesToCheck = @('AzOpsState', 'AzOpsAzManagementGroup', 'AzOpsSubscriptions')
    )

    # Create array to catch null variables
    $NullVariables = @()
    # Iterate through each variable and throw error if not set
    foreach ($Variable in $VariablesToCheck) {
        if (-not(Get-Variable -Scope Global -Name $Variable -ErrorAction Ignore)) {
            $NullVariables += $Variable
            Write-AzOpsLog -Level Verbose -Topic "Test-AzOpsVariables" -Message "Required variable `"$Variable`" (NOT SET)"
        }
        else {
            Write-AzOpsLog -Level Verbose -Topic "Test-AzOpsVariables" -Message "Required variable `"$Variable`" (FOUND)"
        }
    }
    if ($NullVariables) {
        return $false
    }
    else {
        return $true
    }

}