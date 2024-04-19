del(.ResourceId, .id, .tenantId, .subscriptionId, .properties.policyType, .properties.policyDefinitions[].definitionVersion, .properties.metadata.createdOn, .properties.metadata.updatedOn, .properties.metadata.createdBy, .properties.metadata.updatedBy)
| walk(if type == "object" then with_entries(
    select(.value != "" or (.key == "defaultValue" and .value == "")))
    else . end)