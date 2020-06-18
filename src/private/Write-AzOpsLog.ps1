function Write-AzOpsLog {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Information", "Warning", "Error", "Verbose", "Debug")]
        [string]$Level,

        [Parameter(Mandatory = $false)]
        [string]$Topic,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Timestamp
    )

    begin {
        if ($Timestamp) {
            $timestamp = Get-Date -Format FileDateTimeUniversal
            $log = ("[$timestamp]" + " " + "($topic)" + " " + $message)
        }
        else {
            $timestamp = ""
            $log = ("($topic)" + " " + $message)
        }   
    }

    process {
        switch ($level) {
            "Information" {
                Write-Information -MessageData $log -InformationAction Continue
            }
            "Warning" {
                Write-Warning -Message $log
            }
            "Error" {
                Write-Error -Message $log
            }
            "Verbose" {
                Write-Verbose -Message $log
            }
            "Debug" {
                Write-Debug -Message $log
            }
        }
    }
    
    end { }

}