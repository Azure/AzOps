{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "input": {
            "value": .
        }
    }
}
| del(.. | select(. == null))
| del(.. | select(. == ""))