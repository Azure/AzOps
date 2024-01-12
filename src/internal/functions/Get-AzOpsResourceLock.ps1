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
        if ($ScopeObject.Type -notin 'resourceGroups', 'subscriptions') {
            return
        }
        switch ($ScopeObject.Type) {
            subscriptions {
                # ScopeObject is a subscription
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsResourceLock.Subscription' -LogStringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
            }
            resourcegroups {
                # ScopeObject is a resourcegroup
                Write-AzOpsMessage -LogLevel Verbose -LogString 'Get-AzOpsResourceLock.ResourceGroup' -LogStringValues $ScopeObject.ResourceGroup -Target $ScopeObject
            }
        }
        try {
            $parameters = @{
                Scope = $ScopeObject.Scope
            }
            # Gather resource locks at scopeObject with retry and backoff support from Invoke-AzOpsScriptBlock
            $resourceLocks = Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                Get-AzResourceLock @parameters -AtScope -ErrorAction Stop | Where-Object {$($_.ResourceID.Substring(0, $_.ResourceId.LastIndexOf('/'))) -Like ("$($parameters.Scope)/providers/Microsoft.Authorization/locks")}
            } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Get-AzOpsResourceLock.Failed' -LogStringValues $_
        }
        if ($resourceLocks) {
            # Process each resource lock
            foreach ($lock in $resourceLocks) {
                $lock | ConvertTo-AzOpsState -StatePath $StatePath
            }
        }
    }
}