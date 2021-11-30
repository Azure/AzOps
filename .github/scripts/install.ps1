function Install-SourceModule {

    [CmdletBinding()]
    param(
        $Repository,

        $Branch = "main"
    )

    process {
        $url = "https://api.github.com/repos/{0}/zipball/{1}" -f $Repository, $Branch
        Write-Verbose "Module Url: $($url)"

        $moduleName = $Repository.split('/')[-1]
        Write-Verbose "Module Name: $($moduleName)"

        $tempPath = [System.IO.Path]::GetTempPath()

        $moduleArchivePath = Join-Path -Path $tempPath -ChildPath "$($moduleName).zip"
        Write-Verbose "Module Archive: $($moduleArchivePath)"

        $null = Invoke-RestMethod $url -OutFile $moduleArchivePath

        $null = Expand-Archive -Path $moduleArchivePath -DestinationPath "$tempPath" -Force

        $Repository = $Repository.Replace("/", "-")

        $moduleSource = Get-ChildItem $tempPath | Where-Object Name -like "$Repository*"
        Write-Verbose "Module Source: $($moduleSource)"

        $moduleFiles = Get-ChildItem "$moduleSource/src"

        $modulesPath = Join-Path -Path $HOME -ChildPath ".local/share/powershell/Modules"
        Write-Verbose "Modules Path: $($modulesPath)"

        $modulePath = Join-Path -Path $modulesPath -ChildPath $moduleName
        Write-Verbose "Module Path: $($modulePath)"

        $moduleManifest = Get-ChildItem $moduleFiles -Include "$moduleName.psd1" -Recurse
        Write-Verbose "Module Manifest: $($moduleManifest)"

        $moduleVersion = (Get-Content -Raw $moduleManifest.FullName | Invoke-Expression).ModuleVersion
        Write-Verbose "Module Version: $($moduleVersion)"

        $modulePath = Join-Path -Path $modulePath -ChildPath $moduleVersion
        Write-Verbose "Module Path: $($modulePath)"

        $null = New-Item -ItemType directory -Path $modulePath -Force

        $null = Copy-Item $moduleFiles -Destination $modulePath -Force -Recurse
    }

}