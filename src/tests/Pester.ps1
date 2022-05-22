param (
    $TestGeneral = $false,

    $TestFunctions = $false,

    $TestFunctional = $false,

    $TestIntegration = $false,

    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    $Output = "None",

    $Include = "*",

    $Exclude = @("Help.Tests.ps1", "PSScriptAnalyzer.Tests.ps1")
)

Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 3

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module AzOps -ErrorAction Ignore

Import-Module "$PSScriptRoot\..\AzOps.psd1" -Scope Global
Import-Module "$PSScriptRoot\..\AzOps.psm1" -Scope Global -Force

# Need to import explicitly so we can use the configuration class
Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test results folder"
$null = New-Item -Path "$PSScriptRoot\..\.." -Name results -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()
$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true

#region Run General Tests
if ($TestGeneral) {
    Write-PSFMessage -Level Important -Message "Proceeding with general tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [PSCustomObject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion Run General Tests

$global:__pester_data.ScriptAnalyzer | Out-Host

#region Function Tests
if ($TestFunctions) {
    Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "Executing $($file.Name)"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [PSCustomObject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#region Function Tests

$global:__pester_data.ScriptAnalyzer | Out-Host

#region Run Functional Tests
if ($TestFunctional) {
    Write-PSFMessage -Level Important -Message "Proceeding with functional tests"
    try {
        $functionalTestsScript = (Get-ChildItem "$PSScriptRoot\functional" | Where-Object Name -like "*.Tests.ps1")
        & $functionalTestsScript.VersionInfo.FileName -cleanupEnvironment $true
        $functionalTestDeploymentOutput = & $functionalTestsScript.VersionInfo.FileName -setupEnvironment $true
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Functional tests initialize failed" -Exception $_.Exception
        throw
    }
    foreach ($file in (Get-ChildItem "$PSScriptRoot\functional" -Recurse | Where-Object Name -eq "scenario.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "Executing <c='em'>$($file.Name)</c>"
        $container = New-PesterContainer -Path $file.FullName -Data @{
            functionalTestFilePaths = $functionalTestDeploymentOutput.functionalTestFilePaths;
            functionalTestDeploy = $functionalTestDeploymentOutput.functionalTestDeploy
        }
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName)-$(Get-Random -Maximum 500).xml"
        $config.Run.Container = $container
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [PSCustomObject]@{
                    ExpandedPath   = $_.Expandedpath
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
    try {
        & $functionalTestsScript.VersionInfo.FileName -cleanupEnvironment $true
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Functional tests cleanup failed" -Exception $_.Exception
        throw
    }
}
#endregion Run Functional Tests

#region Run Integration Tests
if ($TestIntegration) {
    Write-PSFMessage -Level Important -Message "Proceeding with integration tests"
    foreach ($file in (Get-ChildItem "$PSScriptRoot\integration" | Where-Object Name -like "*.Tests.ps1")) {
        if ($file.Name -notlike $Include) { continue }
        if ($Exclude -contains $file.Name) { continue }

        Write-PSFMessage -Level Significant -Message "Executing <c='em'>$($file.Name)</c>"
        $config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\..\results" "$($file.BaseName).xml"
        $config.Run.Path = $file.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = $Output
        $results = Invoke-Pester -Configuration $config
        foreach ($result in $results) {
            $totalRun += $result.TotalCount
            $totalFailed += $result.FailedCount
            $result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
                $testresults += [PSCustomObject]@{
                    Block   = $_.Block
                    Name    = "It $($_.Name)"
                    Result  = $_.Result
                    Message = $_.ErrorRecord.DisplayErrorMessage
                }
            }
        }
    }
}
#endregion Run Integration Tests

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -eq 0) {
    Write-PSFMessage -Level Critical -Message "All <c='em'>$totalRun</c> tests executed without a single failure!"
}
else {
    Write-PSFMessage -Level Critical -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed!"
}

if ($totalFailed -gt 0) {
    throw "$totalFailed / $totalRun tests failed!"
}
