<#
.SYNOPSIS
    This cmdlet serializes and, depending on the input, sorts powershell objects for deterministic output.
.DESCRIPTION
    This cmdlet serializes and, depending on the input, sorts powershell objects for deterministic output.
.EXAMPLE
    #Convert the object to [PSCustomObject] without ordering to be able to alter/change all properties
    $subscription = Get-AzSubscription | Select-Object -First 1
    $subscription | ConvertTo-AzOpsObject

    Id                        : 2f68ca09-59d9-4ab5-ad11-c54872bfa28d
    Name                      : bu1-neu-msx1
    State                     : Enabled
    SubscriptionId            : 2f68ca09-59d9-4ab5-ad11-c54872bfa28d
    TenantId                  : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    CurrentStorageAccountName :
    ExtendedProperties        : @{Environment=AzureCloud; Account=96657a67-755f-4f93-8b8e-317f9a107323; Tenants=3fc1081d-6105-4e19-b60c-1ec1252cf560}
    CurrentStorageAccount     :
.EXAMPLE
    #Convert the object to [PSCustomObject] and order all properties in alphabetical order
    $subscription = Get-AzSubscription | Select-Object -First 1
    $subscription | ConvertTo-AzOpsObject -OrderObject

    CurrentStorageAccount     :
    CurrentStorageAccountName :
    ExtendedProperties        : {Account, Environment, Tenants}
    Id                        : 2f68ca09-59d9-4ab5-ad11-c54872bfa28d
    Name                      : bu1-neu-msx1
    State                     : Enabled
    SubscriptionId            : 2f68ca09-59d9-4ab5-ad11-c54872bfa28d
    TenantId                  : 3fc1081d-6105-4e19-b60c-1ec1252cf560
.INPUTS
    Any [PSObject] or [PSCustomObject]
.OUTPUTS
    Resource in AzOpsState json format or object returned as [PSCustomObject] depending on parameters used
#>
function ConvertTo-AzOpsObject {

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        #Inputobject to serialize
        [Parameter(ValueFromPipeline)]
        $InputObject,
        #Used if the object properties should be ordered in alphabetical order
        [Parameter(Mandatory = $false)]
        [switch]$OrderObject
    )

    begin {}

    process {
        #If [switch]$OrderObject has been used, go through each property recursively to ensure it is sorted/ordered properly
        if ($PSBoundParameters["OrderObject"]) {
            #Check input object type
            if ($InputObject -is [PSObject] -or [PSCustomObject] -and $InputObject -isnot [string] -and $inputobject -isnot [array] -and $InputObject -isnot [System.Collections.ICollection] -and $inputobject -isnot [Microsoft.Azure.Commands.ResourceManager.Cmdlets.Implementation.Policy.PsPolicyType]) {
                #Create ordered PSCustomObject
                $Object = [PSCustomObject][ordered]@{ }
                #Sort properties
                $Properties = $InputObject.PSObject.Properties | Sort-Object -Property Name
                #Loop through properties recursively
                foreach ($property in $Properties ) {
                    # $value = ConvertTo-AzOpsObject -InputObject $property.Value -OrderObject:$OrderObject
                    # Add-Member -InputObject $Object -Name $property.Name -Value $value -MemberType NoteProperty -Force
                    if ($property.Value) {
                        $value = ConvertTo-AzOpsObject -InputObject $property.Value -OrderObject:$OrderObject
                        Add-Member -InputObject $Object -Name $property.Name -Value $value -MemberType NoteProperty -Force
                    }
                    else {
                        Add-Member -InputObject $Object -Name $property.Name -Value $null -MemberType NoteProperty -Force
                    }
                }
                Write-Output -NoEnumerate -InputObject $Object
            }
            #Handle hash tables and dictionaries
            elseif ($InputObject -is [System.Collections.ICollection] -and $InputObject -isnot [string] -and $inputobject -isnot [array]) {
                $hash = [ordered]@{ }
                $keys = ($Inputobject.Keys | Sort-Object)
                foreach ($key in $keys ) {
                    $hash[$key] = ConvertTo-AzOpsObject -InputObject $inputobject[$key] -OrderObject:$OrderObject
                }
                $hash
            }
            #Handle arrays
            elseif ($InputObject -is [array]) {

                if ($InputObject.count -eq 0) {
                    #Return empty array if empty array (powershell will by default return $null)
                    return , @()
                }
                elseif ($InputObject.count -eq 1) {
                    #Return array with count 1 as array (powershell will automatically convert it to a string)
                    return , @($InputObject)
                }
                else {
                    #Return the array
                    $InputObject | Sort-Object
                }
            }
            else {
                #If the object isn't a collection, hash table or other psobject - it is a string
                $InputObject | Sort-Object
            }
        }
        else {
            #If [switch]$OrderObject has not been used, route the object through ConvertTo/ConvertFrom-Json to create a PSCustomObject to be able to modify/remove the properties
            $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        }
    }

    end {}

}
