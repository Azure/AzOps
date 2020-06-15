function Compare-AzOpsState {

    [CmdletBinding()]
    param (
        [Parameter()]
        $ref,
        [Parameter()]
        $diffref
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        #Write-Verbose "REf Object Type $($ref.gettype().tostring())"
        if ($ref -is [array]) {
            if ($ref.count -ne $diffref.count) {
                return $true
            }
            else {
                For ($r = 0; $r -lt $ref.count  ; $r++) {
                    $result = (Compare-AzOpsState $ref[$r] $diffref[$r])
                    if ($result) {
                        return $result
                    }
                }
            }
        }

        if (($ref | Get-Member -MemberType NoteProperty).count -eq 0) {
            if ((Compare-Object ($ref) ($diffref))) {
                Write-Verbose "-----------"
                Write-Verbose "Configuration Drift for Property: $($property.Name)"
                Write-Verbose "-----------"
                return $true
            }
        }
        else {
            foreach ($property in ($ref | Get-Member -MemberType NoteProperty)) {
                if (-not $property.Definition.StartsWith('datetime')) {
                    Write-Verbose "Processing Child Poperty: $($property.Name)"
                    if ($property.Definition.StartsWith('string') -or $property.Definition.StartsWith('bool')) {

                        $refObj1 = ($ref | Select-Object -ExpandProperty $property.Name -ErrorAction:SilentlyContinue )
                        $refObj2 = ($diffref | Select-Object -ExpandProperty  $property.Name -ErrorAction:SilentlyContinue)

                        if ( ($null -ne $refObj1) -and ($null -ne $refObj2)) {
                            if ((Compare-Object $refObj1 $refObj2 )) {
                                Write-Verbose "-----------"
                                Write-Verbose "Configuration Drift for Property: $($property.Name)"
                                Write-Verbose "-----------"
                                return $true
                            }
                        }
                        else {
                            Write-Warning "Proerty not found in either ref or diffref"
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
                                Write-Warning "Proerty not found in either ref or diffref"
                                return $true
                            }
                        }
                        else {
                            Write-Verbose "Ignoring property $($property.Name)"
                        }
                    }
                }
                else {
                    Write-Verbose "Ignoring property $($property.Name)"
                }
            }
        }
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}