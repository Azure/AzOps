# The following SuppressMessageAttribute entries are used to surpress
# PSScriptAnalyzer tests against known exceptions as per:
# https://github.com/powershell/psscriptanalyzer#suppressing-rules
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsState')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsAzManagementGroup')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsSubscriptions')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsExportRawTemplate')]
param ()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3.0

$files = @()
$files += Get-ChildItem -Force -Path ($PSScriptRoot + "/private/")
$files += Get-ChildItem -Force -Path ($PSScriptRoot + "/public/")

foreach ($file in $files) {
    try {
        . $file.FullName
    }
    catch {
        throw "Unable to dot source [$($file.FullName)]"
    }
}

class AzOpsScope {

    [string]$scope
    [string]$type
    [string]$name
    [string]$statepath
    [string]$managementgroup
    [string]$managementgroupDisplayName
    [string]$subscription
    [string]$subscriptionDisplayName
    [string]$resourcegroup
    [string]$resourceprovider
    [string]$resource

    hidden [regex]$regex_tenant = '/$'
    hidden [regex]$regex_managementgroup = '(?i)^/providers/Microsoft.Management/managementgroups/[^/]+$'
    hidden [regex]$regex_managementgroupExtract = '(?i)^/providers/Microsoft.Management/managementgroups/'

    hidden [regex]$regex_subscription = '(?i)^/subscriptions/[^/]*$'
    hidden [regex]$regex_subscriptionExtract = '(?i)^/subscriptions/'

    hidden [regex]$regex_resourceGroup = '(?i)^/subscriptions/.*/resourcegroups/[^/]*$'
    hidden [regex]$regex_resourceGroupExtract = '(?i)^/subscriptions/.*/resourcegroups/'

    hidden [regex]$regex_managementgroupProvider = '(?i)^/providers/Microsoft.Management/managementgroups/[\s\S]*/providers'
    hidden [regex]$regex_subscriptionProvider = '(?i)^/subscriptions/.*/providers'
    hidden [regex]$regex_resourceGroupProvider = '(?i)^/subscriptions/.*/resourcegroups/[\s\S]*/providers'

    hidden [regex]$regex_managementgroupResource = '(?i)^/providers/Microsoft.Management/managementGroups/[\s\S]*/providers/[\s\S]*/[\s\S]*/'
    hidden [regex]$regex_subscriptionResource = '(?i)^/subscriptions/.*/providers/[\s\S]*/[\s\S]*/'
    hidden [regex]$regex_resourceGroupResource = '(?i)^/subscriptions/.*/resourcegroups/[\s\S]*/providers/[\s\S]*/[\s\S]*/'

    AzOpsScope([string]$scope) {
        <#
            .SYNOPSIS

            Gets AzOpsScope based on resource ID

            .DESCRIPTION

            Gets AzOpsScope based on resource ID

            .PARAMETER Name
            Scope == ResourceID

            .INPUTS

            None. You cannot pipe objects to Add-Extension.

            .OUTPUTS

            System.String. Add-Extension returns a string with the extension
            or file name.

            .EXAMPLE

            New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"

        #>
        $this.InitializeMemberVariables($scope)
    }

    # Overloaded constructors -  repeat member assignments in each constructor definition
    AzOpsScope([System.IO.DirectoryInfo] $path) {
        $this.InitializeMemberVariablesFromPath($path)
    }

    AzOpsScope([System.IO.FileInfo] $path) {
        if (Test-path $path) {
            if ($path.Extension.Equals('.json')) {
                $resourcepath = Get-Content ($path) | ConvertFrom-Json -AsHashtable

                if (
                    ($null -ne $resourcepath) -and
                    ($resourcepath.Keys -contains "`$schema") -and
                    ($resourcepath.Keys -contains "parameters") -and
                    ($resourcepath.parameters.Keys -contains "input")
                ) {
                    <#
                        {
                            "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
                            "contentVersion": "1.0.0.0",
                            "parameters": {
                                "input": {
                                    "value": {
                                        "Id": "/providers/Microsoft.Management/managementGroups/contoso"
                                    }
                                }
                            }
                        }
                    #>
                    if ($resourcepath.parameters.input.value.Keys -contains "ResourceId") {
                        # Resource
                        $this.InitializeMemberVariables($resourcepath.parameters.input.value.ResourceId)
                    }
                    elseif ($resourcepath.parameters.input.value.Keys -contains "Id") {
                        # ManagementGroup and Subscription
                        $this.InitializeMemberVariables($resourcepath.parameters.input.value.Id)
                    }
                    else {
                        # Try to determine based on directory
                        $this.InitializeMemberVariablesFromPath($path.Directory)
                    }
                }
                else {
                    # Try to determine based on directory
                    $this.InitializeMemberVariablesFromPath($path.Directory)
                }
            }
            else {
                $this.InitializeMemberVariablesFromPath($path.Directory)
            }
        }
    }

    hidden [void] InitializeMemberVariablesFromPath([System.IO.DirectoryInfo] $path) {

        if ($path.FullName -eq (Get-Item $global:AzOpsState).FullName) {
            # Root tenant path
            $this.InitializeMemberVariables("/")
        }
        else {

            # Always look into .AzState folder regardless of path specified
            if (-not ($path.FullName.EndsWith('.azstate', "CurrentCultureIgnoreCase"))) {
                $path = Join-Path $path -ChildPath '.AzState'
            }
            $managementGroupFileName = "Microsoft.Management_managementGroups-*.parameters.json"
            $subscriptionFileName = "Microsoft.Subscription_subscriptions-*.parameters.json"
            $resourceGroupFileName = "Microsoft.Resources_resourceGroups-*.parameters.json"

            if (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $managementGroupFileName }) {
                $mg = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $managementGroupFileName }) | ConvertFrom-Json
                if ($mg.parameters.input.value.Id) {
                    $this.InitializeMemberVariables($mg.parameters.input.value.Id)
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "$managementGroupFileName does not contain .parameters.input.value.Id"
                }
            }
            elseif (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $subscriptionFileName }) {
                $sub = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $subscriptionFileName }) | ConvertFrom-Json
                if ($sub.parameters.input.value.Id) {
                    $this.InitializeMemberVariables($sub.parameters.input.value.Id)
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "Microsoft.Subscription-subscriptions* does not contain .parameters.input.value.Id"
                }
            }
            elseif (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $resourceGroupFileName }) {
                $rg = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $resourceGroupFileName }) | ConvertFrom-Json
                if ($rg.parameters.input.value.ResourceId) {
                    $this.InitializeMemberVariables($rg.parameters.input.value.ResourceId)
                }
                else {
                    Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "$resourceGroupFileName does not contain .parameters.input.value.ResourceId"
                }
            }
            else {
                Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "Unable to determine AzOpsScope from file: $path"
            }
        }
    }
    hidden [void] InitializeMemberVariables([string] $scope) {

        $this.scope = $scope

        if ($this.IsResource()) {
            $this.type = "resource"
            $this.name = $this.IsResource()
            $this.subscription = $this.GetSubscription()
            $this.subscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.managementgroup = $this.GetManagementGroup()
            $this.managementgroupDisplayName = $this.GetManagementGroupName()
            $this.resourcegroup = $this.GetResourceGroup()
            $this.resourceprovider = $this.IsResourceProvider()
            $this.resource = $this.GetResource()
            if ($global:AzOpsExportRawTemplate -eq 1) {
                $this.statepath = $this.GetAzOpsResourcePath() + ".json"
            }
            else {
                $this.statepath = $this.GetAzOpsResourcePath() + ".parameters.json"
            }
        }
        elseif ($this.IsResourceGroup()) {
            $this.type = "resourcegroups"
            $this.name = $this.IsResourceGroup()
            $this.subscription = $this.GetSubscription()
            $this.subscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.managementgroup = $this.GetManagementGroup()
            $this.managementgroupDisplayName = $this.GetManagementGroupName()
            $this.resourcegroup = $this.GetResourceGroup()
            # $this.statepath = (join-path $this.FindAzOpsStatePath() -ChildPath "resourcegroup.json")
            if ($global:AzOpsExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources_resourceGroups-$($this.resourcegroup).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources_resourceGroups-$($this.resourcegroup).parameters.json")
            }
        }
        elseif ($this.IsSubscription()) {
            $this.type = "subscriptions"
            $this.name = $this.IsSubscription()
            $this.subscription = $this.GetSubscription()
            $this.subscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.managementgroup = $this.GetManagementGroup()
            $this.managementgroupDisplayName = $this.GetManagementGroupName()
            if ($global:AzOpsExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription_subscriptions-$($this.subscription).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription_subscriptions-$($this.subscription).parameters.json")
            }

        }
        elseif ($this.IsManagementGroup()) {
            $this.type = "managementGroups"
            $this.name = $this.GetManagementGroup()
            $this.managementgroup = ($this.GetManagementGroup()).Trim()
            $this.managementgroupDisplayName = ($this.GetManagementGroupName()).Trim()
            # $this.statepath = (join-path $this.FindAzOpsStatePath() -ChildPath "managementgroup.json")
            if ($global:AzOpsExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsManagementGroupPath($this.managementgroup) -ChildPath ".AzState\Microsoft.Management_managementGroups-$($this.managementgroup).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsManagementGroupPath($this.managementgroup) -ChildPath ".AzState\Microsoft.Management_managementGroups-$($this.managementgroup).parameters.json")
            }
        }
        elseif ($this.IsRoot()) {
            $this.type = "root"
            $this.name = "/"
            $this.statepath = $global:AzOpsState
        }
    }

    [String] ToString() {
        return $this.scope
    }

    [bool] IsRoot() {
        if ( ($this.scope -imatch $this.regex_tenant)) {
            return  $true
        }
        return $false
    }
    [bool] IsManagementGroup() {
        if ( ($this.scope -imatch $this.regex_managementgroup)) {
            return  $true
        }
        return $false
    }

    [string] IsSubscription() {
        # if ( ($this.scope.Split('/').count -eq 3) -and ($this.scope -imatch $this.regex_subscription)) {
        if ( ($this.scope -imatch $this.regex_subscription)) {
            return ( $this.scope.Split('/')[2])
        }
        return $null
    }
    [string] IsResourceGroup () {
        # if (($this.scope.Split('/').count -eq 5) -and ($this.scope -imatch $this.regex_resourceGroup)) {
        if (($this.scope -imatch $this.regex_resourceGroup)) {
            return ($this.scope.Split('/')[4])
        }
        return $null
    }
    [string] IsResourceProvider () {

        if ($this.scope -imatch $this.regex_managementgroupProvider) {
            return ( ($this.regex_managementgroupProvider.Split($this.scope) | Select-Object -last 1) -split '/')[1]
        }
        if ($this.scope -imatch $this.regex_subscriptionProvider) {
            return ( ($this.regex_subscriptionProvider.Split($this.scope) | Select-Object -last 1) -split '/')[1]
        }
        if ($this.scope -imatch $this.regex_resourceGroupProvider) {
            return ( ($this.regex_resourceGroupProvider.Split($this.scope) | Select-Object -last 1) -split '/')[1]
        }

        return $null
    }
    [string] IsResource () {

        if ($this.scope -imatch $this.regex_managementgroupResource) {
            return ($this.regex_managementgroupResource.Split($this.scope) | Select-Object -last 1)
        }
        if ($this.scope -imatch $this.regex_subscriptionResource) {
            return ($this.regex_subscriptionResource.Split($this.scope) | Select-Object -last 1)
        }
        if ($this.scope -imatch $this.regex_resourceGroupResource) {
            return ($this.regex_resourceGroupResource.Split($this.scope) | Select-Object -last 1)
        }
        return $null
    }

    <#
        Should Return Management Group Name
    #>
    [string] GetManagementGroup() {

        if ($this.GetManagementGroupName()) {
            foreach ($mgmt in $global:AzOpsAzManagementGroup) {
                if ($mgmt.DisplayName -eq $this.GetManagementGroupName()) {
                    return $mgmt.Name
                }
            }
        }
        if ($this.subscription) {
            foreach ($mgmt in $global:AzOpsAzManagementGroup) {
                foreach ($child in $mgmt.Children) {
                    if ($child.DisplayName -eq $this.subscriptionDisplayName) {
                        return $mgmt.Name
                    }
                }
            }
        }
        return $null
    }

    [string] GetAzOpsManagementGroupPath([string]$managementgroupName) {
        if (($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName })) {
            $ParentMgName = ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).parentId -split "/" | Select-Object -Last 1
            if (($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).parentId -and ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $ParentMgName } )) {
                $ParentPath = $this.GetAzOpsManagementGroupPath( (($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).parentId -split '/' | Select-Object -last 1))
                $Childpath = "{0} ({1})" -f ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).DisplayName, ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).Name
                return (join-path $parentPath -ChildPath $ChildPath)
            }
            else {
                $ChildPath = "{0} ({1})" -f ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).DisplayName, ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).Name
                return (join-path $global:AzOpsState -ChildPath $Childpath)
            }
        }
        else {
            Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "Management Group not found: $managementgroupName"
            return $null
        }
    }

    <#
        Should Return Management Group Display Name
    #>
    [string] GetManagementGroupName() {
        if ($this.scope -imatch $this.regex_managementgroupExtract) {
            $mgId = ((($this.scope -split $this.regex_managementgroupExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)

            if ($mgId) {
                Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Querying Global variable for AzOpsAzManagementGroup"
                $mgDisplayName = ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $mgId }).DisplayName
                if ($mgDisplayName) {
                    Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Management Group found in Azure: $($mgDisplayName)"
                    return $mgDisplayName
                }
                else {
                    Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Management Group not found in Azure. Using directory name instead: $($mgId)"
                    return $mgId
                }
            }
        }
        if ($this.subscription) {
            foreach ($mgmt in $global:AzOpsAzManagementGroup) {
                foreach ($child in $mgmt.Children) {
                    if ($child.DisplayName -eq $this.subscriptionDisplayName) {
                        return $mgmt.DisplayName
                    }
                }
            }
        }
        return $null
    }
    [string] GetAzOpsSubscriptionPath() {
        $childpath = "{0} ({1})" -f $this.subscriptionDisplayName, $this.subscription
        return join-path $this.GetAzOpsManagementGroupPath($this.managementgroup) -ChildPath $childpath
    }
    [string] GetAzOpsResourceGroupPath() {

        return join-path $this.GetAzOpsSubscriptionPath()  -ChildPath $this.resourcegroup
    }
    [string] GetSubscription() {
        if ($this.scope -imatch $this.regex_subscriptionExtract) {

            $subId = ((($this.scope -split $this.regex_subscriptionExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)
            $sub = $global:AzOpsSubscriptions | Where-Object { $_.subscriptionId -eq $subId }
            if ($sub) {
                Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "SubscriptionId found in Azure: $($sub.Id)"
                return $sub.subscriptionId
            }
            else {
                Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "SubscriptionId not found in Azure. Using directory name instead: $($subId)"
                return $subId
            }
        }
        return $null
    }
    [string] GetSubscriptionDisplayName() {
        if ($this.scope -imatch $this.regex_subscriptionExtract) {

            $subId = ((($this.scope -split $this.regex_subscriptionExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)
            $sub = $global:AzOpsSubscriptions | Where-Object { $_.subscriptionId -eq $subId }
            if ($sub) {
                Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Subscription DisplayName found in Azure: $($sub.displayName)"
                return $sub.displayName
            }
            else {
                Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Subscription DisplayName not found in Azure. Using directory name instead: $($subId)"
                return $subId
            }
        }
        return $null
    }
    [string] GetResourceGroup() {

        if ($this.scope -imatch $this.regex_resourceGroupExtract) {
            return ((($this.scope -split $this.regex_resourceGroupExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)
        }
        return $null
    }
    [string] GetResource() {

        if ($this.scope -imatch $this.regex_managementgroupProvider) {
            return ( ($this.regex_managementgroupProvider.Split($this.scope) | Select-Object -last 1) -split '/')[2]
        }
        if ($this.scope -imatch $this.regex_subscriptionProvider) {
            return ( ($this.regex_subscriptionProvider.Split($this.scope) | Select-Object -last 1) -split '/')[2]
        }
        if ($this.scope -imatch $this.regex_resourceGroupProvider) {
            return ( ($this.regex_resourceGroupProvider.Split($this.scope) | Select-Object -last 1) -split '/')[2]
        }

        return $null
    }

    [string] GetAzOpsResourcePath() {

        Write-AzOpsLog -Level Debug -Topic "AzOpsScope" -Message "Getting Resource path for: $($this.scope)"
        if ($this.scope -imatch $this.regex_resourceGroupResource) {
            $rgpath = $this.GetAzOpsResourceGroupPath()
            return (Join-Path (Join-Path $rgpath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
        }
        elseif ($this.scope -imatch $this.regex_subscriptionResource) {
            $subpath = $this.GetAzOpsSubscriptionPath()
            return (Join-Path (Join-path $subpath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
        }
        elseif ($this.scope -imatch $this.regex_managementgroupResource) {
            $mgmtPath = $this.GetAzOpsManagementGroupPath($this.managementgroup)
            return (Join-Path (Join-path $mgmtPath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
        }
        Write-AzOpsLog -Level Error -Topic "AzOpsScope" -Message "Unable to determine Resource Scope for: $($this.scope)"
        return $null
    }
}
<#
.SYNOPSIS
    Returns an AzOpsScope for a path or for a scope
.EXAMPLE
    # Return AzOpsScope for a root Management Group scope scope in Azure
    New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"
    scope                      : /providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560
    type                       : managementGroups
    name                       : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    statepath                  : C:\git\cet-northstar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\.AzState\Microsoft.Management_managementGroups-3fc1081d-6105-4e19-b60c-1ec1252cf560.parame
                                ters.json
    managementgroup            : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    managementgroupDisplayName : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    subscription               :
    subscriptionDisplayName    :
    resourcegroup              :
    resourceprovider           :
    resource                   :
.EXAMPLE
    # Return AzOpsScope for a filepath
    New-AzOpsScope -path  "C:\Users\jodahlbo\git\CET-NorthStar\azops\Tenant Root Group\Non-Production Subscriptions\Dalle MSDN MVP\365lab-dcs"
.INPUTS
    Scope
.INPUTS
    Path
.OUTPUTS
    [AzOpsScope]
#>
function New-AzOpsScope {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [OutputType([AzOpsScope])]
        [Parameter(Position = 0, ParameterSetName = "scope", ValueFromPipeline = $true)]
        [string]$scope,
        [Parameter(Position = 0, ParameterSetName = "pathfile", ValueFromPipeline = $true)]
        [string]$path
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        [regex]$regex_findAzStateFileExtension = '(?i)(.AzState)(|\\|\/)$'
    }
    process {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        # Try to get scope based on scope or filepath
        try {
            # Return scope if scope was provided
            if (($PSCmdlet.ParameterSetName -eq "scope") -and $PSCmdlet.ShouldProcess("Create new scope object?")) {
                Write-AzOpsLog -Level Verbose -Topic "New-AzOpsScope" -Message ("Creating new AzOpsScope object using scope [$scope]")
                return [AzOpsScope]::new($scope)
            }
            # Get scope from filepath
            elseif ($PSCmdlet.ParameterSetName -eq "pathfile") {
                # Remove .AzState file extension if present
                $path = $path -replace $regex_findAzStateFileExtension, ''
                if (
                        (Test-Path $path) -and
                        (Test-Path $path -IsValid) -and
                        (Resolve-Path $path).path.StartsWith((Resolve-Path $Global:AzOpsState).Path) -and
                        $PSCmdlet.ShouldProcess("Create new pathfile object?")
                    ) {
                    Write-AzOpsLog -Level Verbose -Topic "New-AzOpsScope" -Message ("Creating new AzOpsScope object using path [$path]")
                    return [AzOpsScope]::new($(Get-Item $path))
                }
            }
            else {
                Write-AzOpsLog -Level Warning -Topic "New-AzOpsScope" -Message "Path not found: $path"
            }
        }
        catch {
            Write-AzOpsLog -Level Error -Topic "New-AzOpsScope" -Message "$_"
        }
    }
    end {
        Write-AzOpsLog -Level Debug -Topic "New-AzOpsScope" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}
Export-ModuleMember -Function * -Alias *
