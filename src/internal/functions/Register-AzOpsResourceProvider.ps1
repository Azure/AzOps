function Register-AzOpsResourceProvider {

    <#
        .SYNOPSIS
            Registers an azure resource provider.
        .DESCRIPTION
            Registers an azure resource provider.
            Assumes an ARM definition of a resource provider as input.
        .PARAMETER FileName
            The path to the file containing an ARM template defining a resource provider.
        .PARAMETER ScopeObject
            The current AzOps scope.
        .EXAMPLE
            PS C:\> Register-ResourceProvider -FileName $fileName -ScopeObject $scopeObject
            Registers an azure resource provider.
    #>

    [CmdletBinding()]
    param (
        [string]
        $FileName,

        [AzOpsScope]
        $ScopeObject
    )

    process {
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Register-AzOpsResourceProvider.Processing' -LogStringValues $ScopeObject, $FileName -Target $ScopeObject
        $currentContext = Get-AzContext
        if ($ScopeObject.Subscription -and $currentContext.Subscription.Id -ne $ScopeObject.Subscription) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Register-AzOpsResourceProvider.Context.Switching' -LogStringValues $currentContext.Subscription.Name, $CurrentAzContext.Subscription.Id, $ScopeObject.Subscription, $ScopeObject.Name -Target $ScopeObject
            try {
                $null = Set-AzContext -SubscriptionId $ScopeObject.Subscription -ErrorAction Stop
            }
            catch {
                Stop-PSFFunction -String 'Register-AzOpsResourceProvider.Context.Failed' -StringValues $ScopeObject.SubscriptionDisplayName -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet -Target $ScopeObject
                throw "Couldn't switch context $_"
            }
        }

        $resourceproviders = Get-Content  $FileName | ConvertFrom-Json
        foreach ($resourceprovider  in $resourceproviders | Where-Object RegistrationState -eq 'Registered') {
            if (-not $resourceprovider.ProviderNamespace) { continue }

            Write-AzOpsMessage -LogLevel Important -LogString 'Register-AzOpsResourceProvider.Provider.Register' -LogStringValues $resourceprovider.ProviderNamespace
            Register-AzResourceProvider -Confirm:$false -Pre -ProviderNamespace $resourceprovider.ProviderNamespace
        }
    }

}