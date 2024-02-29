function Get-AzOpsResource {

    <#
        .SYNOPSIS
            Check if the Azure resource exists.
        .DESCRIPTION
            Check if the Azure resource exists.
        .PARAMETER ResourceId
            The ResourceId to check.
        .PARAMETER ScopeObject
            Object used to set Azure context for operation.
        .EXAMPLE
            > Get-AzOpsResource -ResourceId /subscriptions/6a35d1cc-ae17-4c0c-9a66-1d9a25647b19/resourceGroups/NetworkWatcherRG -ScopeObject $ScopeObject
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceId,
        [Parameter(Mandatory = $true)]
        [AzOpsScope]
        $ScopeObject
    )

    process {
        Set-AzOpsContext -ScopeObject $ScopeObject
        # Check if the resource exists
        if ($ResourceId -match '^/subscriptions/.*/providers/Microsoft.Authorization/locks' -or $ResourceId -match '^/subscriptions/.*/resourceGroups/.*/providers/Microsoft.Authorization/locks') {
            $resource = Get-AzResourceLock | Where-Object { $_.ResourceId -eq $ResourceId } -ErrorAction SilentlyContinue
        }
        else {
            $resource = Get-AzResource -ResourceId $ResourceId -ErrorAction SilentlyContinue
        }
        if ($resource) {
            return $resource
        }
    }
}