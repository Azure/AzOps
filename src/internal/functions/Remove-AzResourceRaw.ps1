function Remove-AzResourceRaw {

    <#
        .SYNOPSIS
            Performs resource deletion in Azure at any scope.
        .DESCRIPTION
            Performs resource deletion in Azure with FullyQualifiedResourceId and ScopeObject.
        .PARAMETER TemplateFilePath
            Path where the ARM templates can be found.
        .PARAMETER TemplateParameterFilePath
            Path where the parameters of the ARM templates can be found.
        .PARAMETER ScopeObject
            Resource to delete.
        .EXAMPLE
            > Remove-AzResourceRaw -ScopeObject $ScopeObject -TemplateFilePath $TemplateFilePath -TemplateParameterFilePath $TemplateParameterFilePath
            Name                           Value
            ----                           -----
            TemplateFilePath               /root/managementgroup/subscription/resourcegroup/template.json
            TemplateParameterFilePath      /root/managementgroup/subscription/resourcegroup/template.parameters.json
            ScopeObject                    ScopeObject
            Status                         success
    #>

    [CmdletBinding()]
    param (
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
            TemplateFilePath = $TemplateFilePath
            TemplateParameterFilePath = $TemplateParameterFilePath
            ScopeObject = $ScopeObject
            Status = 'success'
        }
        # Check if the resource exists
        $resource = Get-AzOpsResource -ScopeObject $ScopeObject -ErrorAction SilentlyContinue
        # Remove the resource if it exists
        if ($resource) {
            try {
                # Set Azure context for removal operation
                Set-AzOpsContext -ScopeObject $ScopeObject
                $null = Remove-AzResource -ResourceId $ScopeObject.Scope -Force -ErrorAction Stop
                $maxAttempts = 4
                $attempt = 1
                $gone = $false
                while ($gone -eq $false -and $attempt -le $maxAttempts) {
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.CheckExistence' -LogStringValues $ScopeObject.Scope
                    Start-Sleep -Seconds 10
                    $tryResource = Get-AzOpsResource -ScopeObject $ScopeObject -ErrorAction SilentlyContinue
                    if (-not $tryResource) {
                        $gone = $true
                    }
                    $attempt++
                }
            }
            catch {
                # Log failure message
                Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzResourceRaw.Resource.Failed' -LogStringValues $ScopeObject.Resource, $ScopeObject.Scope
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