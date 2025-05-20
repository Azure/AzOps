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
        $ScopeObject,

        [string]
        $DeploymentStackName
    )

    process {
        Set-AzOpsContext -ScopeObject $ScopeObject
        if ($DeploymentStackName -and $ScopeObject.Resource -ne 'deploymentStacks') {
            $ScopeObject.Resource = 'deploymentStacks'
        }
        try {
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
                'deploymentStacks' {
                    if ($ScopeObject.ResourceGroup) {
                        if ($DeploymentStackName) {
                            $resource = Get-AzResourceGroupDeploymentStack -Name $DeploymentStackName -ResourceGroupName $ScopeObject.ResourceGroup -ErrorAction SilentlyContinue
                        }
                        else {
                            $resource = Get-AzResourceGroupDeploymentStack -ResourceId $ScopeObject.Scope -ErrorAction SilentlyContinue
                        }

                    }
                    elseif ($ScopeObject.Subscription) {
                        if ($DeploymentStackName) {
                            $resource = Get-AzSubscriptionDeploymentStack -Name $DeploymentStackName -ErrorAction SilentlyContinue
                        }
                        else {
                            $resource = Get-AzSubscriptionDeploymentStack -ResourceId $ScopeObject.Scope -ErrorAction SilentlyContinue
                        }

                    }
                    elseif ($ScopeObject.ManagementGroup) {
                        if ($DeploymentStackName) {
                            $resource = Get-AzManagementGroupDeploymentStack -Name $DeploymentStackName -ManagementGroupId $ScopeObject.ManagementGroup -ErrorAction SilentlyContinue
                        }
                        else {
                            $resource = Get-AzManagementGroupDeploymentStack -ResourceId $ScopeObject.Scope -ErrorAction SilentlyContinue
                        }
                    }
                }
                default {
                    $resource = Get-AzResource -ResourceId $ScopeObject.Scope -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Get-AzOpsResource.Failed' -LogStringValues $_
            return
        }
        if ($resource) {
            return $resource
        }
    }
}