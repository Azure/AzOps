function Set-AzOpsStringLength {

    <#
        .SYNOPSIS
            Takes string input and shortens it according to maximum length.
        .DESCRIPTION
            Takes string input and shortens it according to maximum length.
        .PARAMETER String
            String to shorten.
        .PARAMETER MaxStringLength
            Set the maximum length for returned string, default is 255 characters.
            Maximum filename length is based on underlying execution environments maximum allowed filename character limit of 255 and the additional characters added by AzOps for files measured by buffer <.parameters> <.json> or <.bicep>.
        .EXAMPLE
            > Set-AzOpsStringLength -String "microsoft.recoveryservices_vaults_replicationfabrics_replicationprotectioncontainers_replicationprotectioncontainermappings-test1-migratevault-1470815024_1541289ea1c5c535f89c0788063b3f5af00e91a2c63438851d90ef7143747149_cloud_308af796-701f-4d5d-ba68-a2434abb3c84_defaultrecplicationvm-containermapping"
            Setting the string length for the above example with default character limit returns the following:
            microsoft.recoveryservices_vaults_replicationfabrics_replicationprotectioncontainers_replicationprotectioncontainermappings-test1-migratevault-1470815024_1541289ea1c5c535f89c-BD89FDDC1A27FAD7C0E62CE2AA0A4513193D4F13907CDCF08E540BB5EFBBA9BA
    #>

    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $String,
        [Parameter(Mandatory = $false)]
        [ValidateRange(155,255)]
        [int]
        $MaxStringLength = "255"
    )

    process {
        # Determine required buffer for ending, set buffer according to space required
        $buffer = ".parameters".Length + $(Get-PSFConfigValue -FullName 'AzOps.Core.TemplateParameterFileSuffix').Length
        # Check if string exceed maximum length
        if (($String.Length + $buffer) -gt $MaxStringLength){
            $overSize = $String.Length + $buffer - $MaxStringLength
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsStringLength.ToLong' -LogStringValues $String,$MaxStringLength,$overSize
            # Generate 64-character hash based on input string
            $stringStream = [IO.MemoryStream]::new([byte[]][char[]]$String)
            $stringHash = Get-FileHash -InputStream $stringStream -Algorithm SHA256
            $startOfNameLength = $MaxStringLength - $stringHash.Hash.Length - $buffer - 1
            # Process new name
            if ($startOfNameLength -gt 1) {
                $startOfName = $String.Substring(0,($startOfNameLength))
                $newName = $startofName + '-' + $stringHash.Hash
            }
            else {
                $newName = $stringHash.Hash + $endofName
            }
            # Construct new string with modified name
            $String = $String.Replace($String,$newName)
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsStringLength.Shortened' -LogStringValues $String,$MaxStringLength
            return $String
        }
        else {
            # Return original string, it is within limit
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Set-AzOpsStringLength.WithInLimit' -LogStringValues $String,$MaxStringLength
            return $String
        }
    }
}