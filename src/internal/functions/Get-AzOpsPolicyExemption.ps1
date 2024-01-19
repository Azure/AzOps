function Get-AzOpsPolicyExemption {

    <#
        .SYNOPSIS
            Discover all custom policy exemptions at the provided scope (Management Groups, subscriptions or resource groups)
        .DESCRIPTION
            Discover all custom policy exemptions at the provided scope (Management Groups, subscriptions or resource groups)
        .PARAMETER ScopeObject
            The scope object representing the azure entity to retrieve excemptions for.
        .EXAMPLE
            > Get-AzOpsPolicyExemption -ScopeObject (New-AzOpsScope -Scope /providers/Microsoft.Management/managementGroups/contoso -StatePath $StatePath)
            Discover all custom policy exemptions deployed at Management Group scope
    #>

    [OutputType([Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyExemption])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]
        $ScopeObject
    )

    process {
        if ($ScopeObject.Type -notin 'resourceGroups', 'subscriptions', 'managementGroups') {
            return
        }

        switch ($ScopeObject.Type) {
            managementGroups {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyExemption.ManagementGroup' -LogStringValues $ScopeObject.ManagementGroupDisplayName, $ScopeObject.ManagementGroup -Target $ScopeObject
            }
            subscriptions {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyExemption.Subscription' -LogStringValues $ScopeObject.SubscriptionDisplayName, $ScopeObject.Subscription -Target $ScopeObject
            }
            resourcegroups {
                Write-AzOpsMessage -LogLevel Debug -LogString 'Get-AzOpsPolicyExemption.ResourceGroup' -LogStringValues $ScopeObject.ResourceGroup -Target $ScopeObject
            }
        }
        try {
            $parameters = @{
                Scope = $ScopeObject.Scope
            }
            # Gather policyExemption with retry and backoff support from Invoke-AzOpsScriptBlock
            Invoke-AzOpsScriptBlock -ArgumentList $parameters -ScriptBlock {
                Get-AzPolicyExemption @parameters -WarningAction SilentlyContinue -ErrorAction Stop | Where-Object ResourceId -match $parameters.Scope
            } -RetryCount 3 -RetryWait 5 -RetryType Exponential -ErrorAction Stop
        }
        catch {
            Write-AzOpsMessage -LogLevel Warning -LogString 'Get-AzOpsPolicyExemption.Failed' -LogStringValues $ScopeObject.Scope
        }
    }

}