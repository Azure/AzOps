function Register-AzOpsProviderFeature {

    <#
        .SYNOPSIS
            Registers a provider feature from ARM.
        .DESCRIPTION
            Registers a provider feature from ARM.
        .PARAMETER FileName
            Path to the ARM template file representing a provider feature.
        .PARAMETER ScopeObject
            The current AzOps scope.
        .EXAMPLE
            PS C:\> Register-ProviderFeature -FileName $file -ScopeObject $scopeObject
            Registers a provider feature from ARM.
    #>

    [CmdletBinding()]
    param (
        [string]
        $FileName,

        [AzOpsScope]
        $ScopeObject
    )

    process {
        #TODO: Clarify original function design intent

        # Get Subscription ID from scope (since Subscription ID is not available for Resource Groups and Resources)
        Write-AzOpsMessage -LogLevel Verbose -LogString 'Register-AzOpsProviderFeature.Processing' -LogStringValues $ScopeObject, $FileName -Target $scopeObject
        $currentContext = Get-AzContext
        if ($ScopeObject.Subscription -and $currentContext.Subscription.Id -ne $ScopeObject.Subscription) {
            Write-AzOpsMessage -LogLevel Verbose -LogString 'Register-AzOpsProviderFeature.Context.Switching' -LogStringValues $currentContext.Subscription.Name, $CurrentAzContext.Subscription.Id, $ScopeObject.Subscription, $ScopeObject.Name -Target $scopeObject
            try {
                $null = Set-AzContext -SubscriptionId $ScopeObject.Subscription -ErrorAction Stop
            }
            catch {
                Stop-PSFFunction -String 'Register-AzOpsProviderFeature.Context.Failed' -StringValues $ScopeObject.SubscriptionDisplayName -ErrorRecord $_ -EnableException $true -Cmdlet $PSCmdlet -Target $ScopeObject
                throw "Couldn't switch context $_"
            }
        }

        $providerFeatures = Get-Content  $FileName | ConvertFrom-Json
        foreach ($providerFeature in $providerFeatures) {
            if ($ProviderFeature.FeatureName -and $ProviderFeature.ProviderName) {
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Register-AzOpsProviderFeature.Provider.Feature' -LogStringValues $ProviderFeature.FeatureName, $ProviderFeature.ProviderName -Target $scopeObject
                Register-AzProviderFeature -Confirm:$false -ProviderNamespace $ProviderFeature.ProviderName -FeatureName $ProviderFeature.FeatureName
            }
        }
    }

}