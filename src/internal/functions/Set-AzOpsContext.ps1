function Set-AzOpsContext {

    <#
        .SYNOPSIS
            Changes the currently active azure context to the subscription of the specified scope object.
        .DESCRIPTION
            Changes the currently active azure context to the subscription of the specified scope object.
        .PARAMETER ScopeObject
            The scope object [AzOpsScope] into which context to change.
        .EXAMPLE
            > Set-AzOpsContext -ScopeObject $scopeObject
            Changes the current context to the subscription of $scopeObject.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ScopeObject
    )

    begin {
        $context = Get-AzContext
    }

    process {
        if (-not $ScopeObject.Subscription) { return }
        if ($context.Subscription.Id -ne $ScopeObject.Subscription) {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsContext.Change' -LogStringValues $context.Subscription.Name, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
            $null = Set-AzContext -SubscriptionId $scopeObject.Subscription -WhatIf:$false
        }
    }
}