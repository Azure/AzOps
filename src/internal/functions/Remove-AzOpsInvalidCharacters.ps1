function Remove-AzOpsInvalidCharacters {

    <#
        .SYNOPSIS
            Takes string input and removes invalid characters.
        .DESCRIPTION
            Takes string input and removes invalid characters.
        .PARAMETER String
            String to remove invalid characters from.
        .PARAMETER Override
            Accepts input to skip selected invalid characters.
        .EXAMPLE
            > Remove-AzOpsInvalidCharacters -String "microsoft.operationalinsights_workspaces_savedsearches-fgh341_logmanagement(fgh343)_logmanagement|countofiislogentriesbyhostrequestedbyclient.json"
            Function returns with the '|' invalid character removed:
            microsoft.operationalinsights_workspaces_savedsearches-fgh341_logmanagement(fgh343)_logmanagementcountofiislogentriesbyhostrequestedbyclient.json
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $String,
        [array]
        $InvalidChars = @('"','<','>','|','►','◄','↕','‼','¶','§','▬','↨','↑','↓','→','∟','↔','*','?','\','/',':'),
        [array]
        $Override
    )

    process {
        # If Override has been provided remove them from InvalidChars
        if ($Override) {
            $InvalidChars = Compare-Object -ReferenceObject $InvalidChars -DifferenceObject $Override -PassThru
        }
        # Check if string contains invalid characters
        $pattern = $InvalidChars | Out-String -NoNewline
        if ($String -match "[$pattern]") {
            Write-PSFMessage -Level Verbose -String 'Remove-AzOpsInvalidCharacters.Invalid' -StringValues $String -FunctionName 'Remove-AzOpsInvalidCharacters'
            # Arrange string into character array
            $fileNameChar = $String.ToCharArray()
            # Iterate over each character in string
            foreach ($character in $fileNameChar) {
                # If character exists in invalid array then replace character
                if ($character -in $InvalidChars) {
                    Write-PSFMessage -Level Verbose -String 'Remove-AzOpsInvalidCharacters.Removal' -StringValues $character, $String -FunctionName 'Remove-AzOpsInvalidCharacters'
                    # Remove invalid character
                    $String = $String.Replace($character.ToString(),'')
                }
            }
        }
        Write-PSFMessage -Level Verbose -String 'Remove-AzOpsInvalidCharacters.Completed' -StringValues $String -FunctionName 'Remove-AzOpsInvalidCharacters'
        # Return processed string
        return $String
    }
}