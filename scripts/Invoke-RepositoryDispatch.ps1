
function Invoke-RepositoryDispatch {
    [CmdletBinding(PositionalBinding = $False)]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter GitHub user name')]
        [String]$GitHubUserName,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Enter GitHub password or PAT')]
        [String]$GitHubPAT
    )

    Begin {
        Set-StrictMode -Version 3
        $ErrorActionPreference = 'Stop'

        if ($IsLinux -or $IsMacOS) {
            $NullRedirection = "2>/dev/null"
            $HomeDir = $env:HOME
        }
        if ($IsWindows) {
            $NullRedirection = "2> nul"
            $HomeDir = $env:USERPROFILE
        }

        if (Test-Path -PathType Leaf -Path $HomeDir/.git-credentials) {
            Write-Verbose "Found .git-credentials file, looking for github.com"
            $GitCredentials = Get-Content -Path $HomeDir/.git-credentials | Select-String -Pattern '@github.com'
            if ($GitCredentials) {
                $Credentials = (($GitCredentials -split '/')[2] -split '@')[0]
                Write-Verbose "github.com credentials found in .git-credentials"
            }
            else {
                Write-Verbose "No credentials found for github.com in .git-credentials"
            }
        }

        Write-Verbose "Validating parameters"
        if ($GitHubUserName -xor $GitHubPAT) {
            Write-Error -Message "Must specify both of, or none of, parameters GitHubUsername & GitHubPAT"
        }

        if ($GitHubUserName -and $GitHubPAT) {
            Write-Verbose "Using credentials supplied as parameters"
            $Credentials = "${GitHubUserName}:${GitHubPAT}"
        }
    }

    Process {
        Write-Verbose "Checking if inside Git work tree"
        $InsideGitWorkTree = Invoke-Expression -Command "git rev-parse --is-inside-work-tree $NullRedirection"
        Write-Verbose "InsideGitWorkTree: $InsideGitWorkTree"
        if (!$InsideGitWorkTree) {
            Write-Error -Message "Not inside git work tree"
        }

        Write-Verbose "Checking and parsing remote 'origin'"
        $GitRemotes = Invoke-Expression -Command "git remote -v $NullRedirection"
        try {
            $Origin = ($GitRemotes | Select-String -Pattern 'origin').Line[0]
        }
        catch {
            Write-Error -Message "Could not find git remote called 'origin'"
        }
        finally {}

        $OriginDomain = ($Origin -split '/')[2]
        Write-Verbose "Origin domain: $OriginDomain"
        if ( -not ($OriginDomain.ToLower() -eq 'github.com')) {
            Write-Error -Message "Remote 'origin' is not hosted on github.com: $Origin"
        }

        $GitHubUserOrOrg = ($Origin -split '/')[3]
        Write-Verbose "GitHub user or org: $GitHubUserOrOrg"

        $GitHubRepo = (($Origin -split '/')[4] -split ' ')[0] -replace '.git', ''
        Write-Verbose "GitHub repo: $GitHubRepo"

        $uri = "https://api.github.com/repos/$GitHubUserOrOrg/$GitHubRepo/dispatches"
        $params = @{
            Uri     = $uri
            Headers = @{
                "Accept"        = "application/vnd.github.everest-preview+json"
                "Content-Type"  = "application/json"
                "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("$Credentials"))))"
            }
            Body    = @{
                "event_type" = "activity-logs"
            } | ConvertTo-json
        }

        try {
            Invoke-RestMethod -Method "POST" @params -Verbose:$VerbosePreference
        }
        catch {
            Write-Error "Could not send HTTP POST to: $uri"
        }
        finally {}
    }

    End {
        Write-Verbose "Operation complete"
    }
}

