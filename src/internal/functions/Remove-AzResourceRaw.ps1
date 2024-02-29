function Remove-AzResourceRaw {

    <#
        .SYNOPSIS
            Performs resource deletion in Azure at any scope.
        .DESCRIPTION
            Performs resource deletion in Azure with FullyQualifiedResourceId and ScopeObject.
        .PARAMETER FullyQualifiedResourceId
            Parameter containing FullyQualifiedResourceId of resource to delete.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the parameters of the ARM templates can be found.
        .PARAMETER ScopeObject
            Object used to set Azure context for removal operation.
        .EXAMPLE
            > Remove-AzResourceRaw -FullyQualifiedResourceId '/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.KeyVault/vaults/<vault-name>' -ScopeObject $ScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
            Name                           Value
            ----                           -----
            FullyQualifiedResourceId       /subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.KeyVault/vaults/<vault-name>
            TemplateFilePath               /root/managementgroup/subscription/resourcegroup/template.json
            TemplateParameterFilePath      /root/managementgroup/subscription/resourcegroup/template.parameters.json
            ScopeObject                    ScopeObject
            Status                         success
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FullyQualifiedResourceId,
        [string]
        $TemplateFilePath,
        [string]
        $TemplateParameterFilePath,
        [Parameter(Mandatory = $true)]
        [AzOpsScope]
        $ScopeObject
    )

    process {
        # Construct result object
        $result = [PSCustomObject]@{
            FullyQualifiedResourceId = $FullyQualifiedResourceId
            TemplateFilePath = $TemplateFilePath
            TemplateParameterFilePath = $TemplateParameterFilePath
            ScopeObject = $scopeObject
            Status = 'success'
        }
        # Check if the resource exists
        $resource = Get-AzOpsResource -ResourceId $FullyQualifiedResourceId -ScopeObject $ScopeObject
        # Remove the resource if it exists
        if ($resource) {
            try {
                # Set Azure context for removal operation
                Set-AzOpsContext -ScopeObject $ScopeObject
                $null = Remove-AzResource -ResourceId $FullyQualifiedResourceId -Force -ErrorAction Stop
                $maxAttempts = 4
                $attempt = 1
                $gone = $false
                while ($gone -eq $false -and $attempt -le $maxAttempts) {
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.CheckExistence' -LogStringValues $FullyQualifiedResourceId
                    Start-Sleep -Seconds 10
                    $tryResource = Get-AzOpsResource -ResourceId $FullyQualifiedResourceId -ScopeObject $ScopeObject
                    if (-not $tryResource) {
                        $gone = $true
                    }
                    $attempt++
                }
            }
            catch {
                # Log failure message
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.Failed' -LogStringValues $ScopeObject.resource, $FullyQualifiedResourceId
                $result.Status = 'failed'
            }
        }
        else {
            # Log not found message
            $result.Status = 'notfound'
        }
        # Return result object
        return $result
    }
}