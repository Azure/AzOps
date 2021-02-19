function ConvertTo-CustomObject {

    <#
        .SYNOPSIS
            Converts an object into a PSCustomObject.
        .DESCRIPTION
            Converts an object into a PSCustomObject.
            Fully breaks original data types.
        .PARAMETER InputObject
            Inputobject to serialize
        .PARAMETER OrderObject
            Used if the object properties should be ordered in alphabetical order
        .EXAMPLE
            PS C:\> Get-ChildItem | ConvertTo-CustomObject
            Converts all FileSystemInformation objects to PSCustomObjects
        .EXAMPLE
            PS C:\> Get-ChildItem | ConvertTo-CustomObject -OrderObject
            Converts all FileSystemInformation objects to PSCustomObjects.
            Each object will have its properties sorted alphabeitcally.
    #>

    [Alias('ConvertTo-AzOpsObject')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [AllowNull()]
        $InputObject,

        [switch]
        $OrderObject
    )

    begin {
        $primitives = [int].Assembly.GetTypes().Where{ $_.IsPrimitive }
        # Technically not a primitive, but in the same category for our purposes
        $primitives += [string]
    }

    process {
        if ($null -eq $InputObject) { return }
        if (-not $OrderObject) {
            # if [switch]$OrderObject has not been used, route the object through ConvertTo/ConvertFrom-Json to create a PSCustomObject to be able to modify/remove the properties
            $InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
            return
        }

        #region Handle Dictionaries and Hashtables
        if ($InputObject -is [System.Collections.IDictionary]) {
            $hash = [ordered]@{ }

            foreach ($key in $InputObject.Keys | Sort-Object) {
                $hash[$key] = ConvertTo-CustomObject -InputObject $InputObject[$key] -OrderObject
            }

            $hash
        }
        #endregion Handle Dictionaries and Hashtables
        #region Handle Arrays and lists
        elseif ($InputObject -is [System.Collections.ICollection]) {
            switch ($InputObject.Count) {
                0 { return, @() }
                1 { return, @($InputObject) }
                default { $InputObject | Sort-Object }
            }
        }
        #endregion Handle Arrays and lists
        #region Handle the non-primitive rest
        elseif ($InputObject.GetType() -notin $primitives) {
            $object = [ordered]@{ }

            foreach ($property in $InputObject.PSObject.Properties | Sort-Object -Property Name) {
                $object[$property.Name] = ConvertTo-CustomObject -InputObject $property.Value -OrderObject
            }

            [PSCustomObject]$object
        }
        #endregion Handle the non-primitive rest
        #region Handle Primitives
        else {
            $InputObject
        }
        #endregion Handle Primitives
    }

}