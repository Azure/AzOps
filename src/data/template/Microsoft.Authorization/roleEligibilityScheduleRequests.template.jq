{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "metadata": {
        "_generator": {
            "name": "AzOps"
        }
    },
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": .ResourceType,
            "name": .Name,
            "apiVersion": "2020-10-01",
            "properties": .Properties
        }
    ],
    "outputs": {}
}
| del((.resources[].properties.Condition | nulls), (.resources[].properties.ConditionVersion | nulls), (.resources[].properties.ScheduleInfo.Expiration.EndDateTime | nulls), (.resources[].properties.ScheduleInfo.Expiration.Duration | nulls), (.resources[].properties.ScheduleInfo.Expiration.ExpirationType | nulls), (.resources[].properties.ScheduleInfo.StartDateTime | nulls))