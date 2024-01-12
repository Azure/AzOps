function Remove-AzOpsInvalidCharacter {

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
            > Remove-AzOpsInvalidCharacter -String "microsoft.operationalinsights_workspaces_savedsearches-fgh341_logmanagement(fgh343)_logmanagement|countofiislogentriesbyhostrequestedbyclient.json"
            Function returns with the '|' invalid character removed:
            microsoft.operationalinsights_workspaces_savedsearches-fgh341_logmanagement(fgh343)_logmanagementcountofiislogentriesbyhostrequestedbyclient.json
    #>

    [CmdletBinding()]
    [OutputType([System.String])]
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
            Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsInvalidCharacter.Invalid' -LogStringValues $String
            # Arrange string into character array
            $fileNameChar = $String.ToCharArray()
            # Iterate over each character in string
            foreach ($character in $fileNameChar) {
                # If character exists in invalid array then replace character
                if ($character -in $InvalidChars) {
                    Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsInvalidCharacter.Removal' -LogStringValues $character, $String
                    # Remove invalid character
                    $String = $String.Replace($character.ToString(),'')
                }
            }
        }
        # Always remove square brackets
        $String = $String -replace "(\[|\])",""
        Write-AzOpsMessage -LogLevel InternalComment -LogString 'Remove-AzOpsInvalidCharacter.Completed' -LogStringValues $String
        # Return processed string
        return $String
    }
}