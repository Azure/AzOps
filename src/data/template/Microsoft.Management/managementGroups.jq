del(.Id, .ParentDisplayName, .UpdatedTime, .UpdatedBy, .TenantId) |
    . as $in | {Type, Name, DisplayName, ParentId, ParentName} + $in |
    .|=if (.Children !=null) then .Children|=sort_by(.Name) else . end