# Guide for available variables and working with secrets:
# https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=powershell

# Needs to ensure things are Done Right and only ethical commits to main get built

# Run internal pester tests
& "$PSScriptRoot\..\src\tests\Pester.ps1"