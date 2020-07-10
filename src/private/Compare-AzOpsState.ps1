function Compare-AzOpsState {

    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        $ref,
        [Parameter()]
        $diffref
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Compare-AzOpsState" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Compare-AzOpsState" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Reference Object Type $($ref.gettype().tostring())"
        if ($ref -is [array]) {
            if ($ref.count -ne $diffref.count) {
                return $true
            }
            else {
                For ($r = 0; $r -lt $ref.count ; $r++) {
                    $result = (Compare-AzOpsState $ref[$r] $diffref[$r])
                    if ($result) {
                        return $result
                    }
                }
            }
        }

        if (($ref | Get-Member -MemberType NoteProperty).count -eq 0) {
            if ((Compare-Object ($ref) ($diffref))) {
                Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Found configuration drift for property: $($property.Name)"
                return $true
            }
        }
        else {
            foreach ($property in ($ref | Get-Member -MemberType NoteProperty)) {
                if (-not $property.Definition.StartsWith('datetime')) {
                    Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Processing child property: $($property.Name)"
                    if ($property.Definition.StartsWith('string') -or $property.Definition.StartsWith('bool')) {

                        $refObj1 = ($ref | Select-Object -ExpandProperty $property.Name -ErrorAction:SilentlyContinue )
                        $refObj2 = ($diffref | Select-Object -ExpandProperty  $property.Name -ErrorAction:SilentlyContinue)

                        if ( ($null -ne $refObj1) -and ($null -ne $refObj2)) {
                            if ((Compare-Object $refObj1 $refObj2 )) {
                                Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Found configuration drift for property: $($property.Name)"
                                return $true
                            }
                        }
                        else {
                            Write-AzOpsLog -Level Warning -Topic "Compare-AzOpsState" -Message "Property not found in either ref or diffref"
                            return $true
                        }
                    }
                    elseif ($property.Definition.StartsWith('System.Management.Automation.PSCustomObject') -or $property.Definition.StartsWith('Object[]')) {
                        if (-not ($property.Name -like '*time' )) {
                            $refObj1 = ($ref | Select-Object -ExpandProperty $property.Name -ErrorAction:SilentlyContinue)
                            $refObj2 = ($diffref | Select-Object -ExpandProperty  $property.Name -ErrorAction:SilentlyContinue)

                            if ( ($null -ne $refObj1) -and ($null -ne $refObj2)) {
                                $result = (Compare-AzOpsState $refObj1 $refObj2 )
                                if ($result) {
                                    return $result
                                }
                            }
                            else {
                                Write-AzOpsLog -Level Warning -Topic "Compare-AzOpsState" -Message "Property not found in either ref or diffref"
                                return $true
                            }
                        }
                        else {
                            Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Ignoring property: $($property.Name)"
                        }
                    }
                }
                else {
                    Write-AzOpsLog -Level Verbose -Topic "Compare-AzOpsState" -Message "Ignoring property: $($property.Name)"
                }
            }
        }
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Compare-AzOpsState" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}