function Set-AzOpsContext {

    <#
        .SYNOPSIS
            Changes the currently active azure context to the subscription of the specified scope object.
        .DESCRIPTION
            Changes the currently active azure context to the subscription of the specified scope object.
        .PARAMETER ScopeObject
            The scope object into which context to change.
        .EXAMPLE
            > Set-AzOpsContext -ScopeObject $scopeObject
            Changes the current context to the subscription of $scopeObject.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [AzOpsScope]
        $ScopeObject
    )

    begin {
        $context = Get-AzContext
    }

    process {
        if (-not $ScopeObject.Subscription) { return }

        if ($context.Subscription.Id -ne $ScopeObject.Subscription) {
            Write-PSFMessage -String 'Set-AzOpsContext.Change' -StringValues $context.Subscription.Name, $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription
            Set-AzContext -SubscriptionId $scopeObject.Subscription
        }
    }
}