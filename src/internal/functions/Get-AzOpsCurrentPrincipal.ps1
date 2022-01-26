function Get-AzOpsCurrentPrincipal {
    <#
        .SYNOPSIS
            Gets the objectid/clientid from the current Azure context
        .DESCRIPTION
            Gets the objectid/clientid from the current Azure context
        .PARAMETER Cmdlet
            The $PSCmdlet variable of the calling command.
        .EXAMPLE
            > Get-AzOpsCurrentPrincipal -AzContext $AzContext
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $AzContext = (Get-AzContext)
    )

    process {
        Write-PSFMessage -Level InternalComment -String 'Get-AzOpsCurrentPrincipal.AccountType' -StringValues $AzContext.Account.Type

        switch ($AzContext.Account.Type) {
            'User' {
                $principalObject = (Invoke-AzRestMethod -Uri https://graph.microsoft.com/v1.0/me).Content | ConvertFrom-Json
            }
            'ManagedService' {
                # Get managed identity application id via IMDS (https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-use-vm-token)
                $applicationId = (Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F" -Headers @{ Metadata = $true }).client_id
                $principalObject = Get-AzADServicePrincipal -ApplicationId $applicationId
            }
            'ServicePrincipal' {
                $principalObject = Get-AzADServicePrincipal -ApplicationId $AzContext.Account.Id
            }
        }
        Write-PSFMessage -Level InternalComment -String 'Get-AzOpsCurrentPrincipal.PrincipalId' -StringValues $principalObject.Id
        return $principalObject
    }
}