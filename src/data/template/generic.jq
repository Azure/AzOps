def matches:
  type == "string"
  and test("(?x:
   ^
   (?: \\d{4}-\\d{2}-\\d{2}T
   |   \\w{3},[ ][\\d ]\\d[ ]\\w{3}[ ]\\d{4}
   )
)");

del(.Id, .id, .Properties.provisioningState, .properties.provisioningState, .Properties.state, .properties.state, .Properties.resourceGuid, .properties.resourceGuid) |
    walk(if type=="object"
     then with_entries(if .value|matches then empty else . end)
     else . end)