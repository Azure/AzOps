Register-PSFConfigValidation -Name "stringorempty" -ScriptBlock {

    param (
        $Value
    )

    $Result = New-Object PSObject -Property @{
        Success = $True
        Value   = $null
        Message = ""
    }

    try {
        [string]$data = $Value
    }
    catch {
        $Result.Message = "Not a string: $Value"
        $Result.Success = $False
        return $Result
    }

    if ([string]::IsNullOrEmpty($data)) {
        $data = ""
    }

    if ($data -eq $Value.GetType().FullName) {
        $Result.Message = "Is an object with no proper string representation: $Value"
        $Result.Success = $False
        return $Result
    }

    $Result.Value = $data

    return $Result

}