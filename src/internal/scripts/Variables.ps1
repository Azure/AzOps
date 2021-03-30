# Module Cache for Subscriptions accessible for the current account
$script:AzOpsSubscriptions = @()
# Module Cache for Management Groups that are in scope for this module
$script:AzOpsAzManagementGroup = @()
# Module Cache for Management Group Roots that are in scope for this module, when accepting partial processing
$script:AzOpsPartialRoot = @()
# Module cache to load resource provider version
$script:AzOpsResourceProvider = $null