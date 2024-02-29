function Get-AzOpsResource {

    <#
        .SYNOPSIS
            Check if the Azure resource exists.
        .DESCRIPTION
            Check if the Azure resource exists.
        .PARAMETER ScopeObject
            The Resource to check.
        .EXAMPLE
            > Get-AzOpsResource -ScopeObject $ScopeObject
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AzOpsScope]
        $ScopeObject
    )

    process {
        Set-AzOpsContext -ScopeObject $ScopeObject
        switch ($ScopeObject.Resource) {
            # Check if the resource exist
            'locks' {
                $resource = Get-AzResourceLock -Scope "/subscriptions/$($ScopeObject.Subscription)" -ErrorAction SilentlyContinue | Where-Object { $_.ResourceID -eq $ScopeObject.Scope }
            }
            'policyAssignments' {
                $resource = Get-AzPolicyAssignment -Id $scopeObject.Scope -ErrorAction SilentlyContinue
            }
            'policyDefinitions' {
                $resource = Get-AzPolicyDefinition -Id $scopeObject.Scope -ErrorAction SilentlyContinue
            }
            'policyExemptions' {
                $resource = Get-AzPolicyExemption -Id $scopeObject.Scope -ErrorAction SilentlyContinue
            }
            'policySetDefinitions' {
                $resource = Get-AzPolicySetDefinition -Id $scopeObject.Scope -ErrorAction SilentlyContinue
            }
            'roleAssignments' {
                $resource = Invoke-AzRestMethod -Path "$($scopeObject.Scope)?api-version=2022-04-01" | Where-Object { $_.StatusCode -eq 200 }
            }
            'resourceGroups' {
                $resource = Get-AzResourceGroup -Id $scopeObject.Scope -ErrorAction SilentlyContinue
            }
            default {
                $resource = Get-AzResource -ResourceId $ScopeObject.Scope -ErrorAction SilentlyContinue
            }
        }
        if ($resource) {
            return $resource
        }
    }
}