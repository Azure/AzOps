function Convert-Object {

    <#
        .SYNOPSIS
            Converts the input object based on a transformation hashtable.
        .DESCRIPTION
            Converts the input object based on a transformation hashtable.
            The transformation hashtable can define for each key in the object one of three things:
            - The string value "Remove" will cause the property of that name to be removed.
            - A value of type Hashtable allows nested transformation rules to be applied.
            - Anything else will become the new value of the property (even $null)
            Returns nothing if no property remains.
            Note: This will dissolve the original object reference, even if no change is needed.
        .PARAMETER Transform
            The transformation hashtable.
            Example:
            @{
                Name = "Max"
                MiddleName = "Remove"
                Hair = @{
                    Color = "Black"
                    Style = "Remove"
                }
            }
            This will:
            - replace the "Name" property with the value "Max"
            - remove the "MiddleName" property if present
            - Update the hair property, changing the color sub-property to "Black" and removing the "Style" property if present
        .PARAMETER InputObject
            The object to transform
        .EXAMPLE
            PS C:\> $data | Convert-Object -Transform $transform
            Applies the transformation rule defined in $transform to all objects in $data
            See the parameter help on -Transform for an example of how such a rule might look like.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Transform,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject
    )

    process {
        foreach ($item in $InputObject) {
            if ($null -eq $item) { continue }

            $result = @{ }

            foreach ($property in $item.PSObject.Properties) {
                if ($property.Name -notin $Transform.Keys) {
                    $result[$property.Name] = $property.Value
                    continue
                }

                if ($Transform[$property.Name] -eq "Remove") {
                    continue
                }
                if ($Transform[$property.Name] -is [hashtable]) {
                    $result[$property.Name] = Convert-Object -Transform $Transform [$property.Name] -InputObject $property.Value
                    continue
                }

                $result[$property.Name] = $Transform[$property.Name]
            }

            if ($result.Count -eq 0) { continue }
            [pscustomobject]$result
        }
    }

}