function Get-AzOpsResourceLock {

    <#
        .SYNOPSIS
            Discover resource locks at the provided scope (Subscription or resource group)
        .DESCRIPTION
            Discover resource locks at the provided scope (Subscription or resource group)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve resource locks from.
        .PARAMETER StatePath
            StatePath
        .EXAMPLE
            > Get-AzOpsResourceLock -ScopeObject xxx
            Discover all resource locks deployed at resource group scope
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject,
        [Parameter(Mandatory = $true)]
        $StatePath
    )

    process {
        if ($ScopeObject.Type -notin 'resourcegroups', 'subscriptions') {
            return
        }
        switch ($ScopeObject.Type) {
            subscriptions {
                # ScopeObject is a subscription
                Write-PSFMessage -Level Important -String 'Get-AzOpsResourceLock.Subscription' -StringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
            }
            resourcegroups {
                # ScopeObject is a resourcegroup
                Write-PSFMessage -Level Important -String 'Get-AzOpsResourceLock.ResourceGroup' -StringValues $ScopeObject.ResourceGroup -Target $ScopeObject
            }
        }
        # Gather resource locks at scopeObject
        $resourceLocks = Get-AzResourceLock -Scope $ScopeObject.Scope -AtScope -ErrorAction SilentlyContinue | Where-Object {$($_.ResourceID.Substring(0, $_.ResourceId.LastIndexOf('/'))) -Like ("$($ScopeObject.scope)/providers/Microsoft.Authorization/locks")}
        if ($resourceLocks) {
            # Process each resource lock
            foreach ($lock in $resourceLocks) {
                $lock | ConvertTo-AzOpsState -StatePath $StatePath
            }
        }
    }
}