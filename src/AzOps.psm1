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

    #Overloaded constructors -  repeat member assignments in each constructor definition
    AzOpsScope([System.IO.DirectoryInfo] $path) {
        $this.InitializeMemberVariablesFromPath($path)
    }

    AzOpsScope([System.IO.FileInfo] $path) {
        if (Test-path $path) {
            if ($path.Extension.Equals('.json')) {
                $resourcepath = Get-Content ($path) | ConvertFrom-Json -AsHashtable

                if (
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
                        #Resource
                        $this.InitializeMemberVariables($resourcepath.parameters.input.value.ResourceId)
                    }
                    elseif ($resourcepath.parameters.input.value.Keys -contains "Id") {
                        #ManagementGroup and Subscription
                        $this.InitializeMemberVariables($resourcepath.parameters.input.value.Id)
                    }
                    else {
                        #Try to determine based on directory
                        $this.InitializeMemberVariablesFromPath($path.Directory)
                    }
                }
                else {
                    #Try to determine based on directory
                    $this.InitializeMemberVariablesFromPath($path.Directory)
                }
            }
            else {
                $this.InitializeMemberVariablesFromPath($path.Directory)
            }
        }
    }

    hidden [void] InitializeMemberVariablesFromPath([System.IO.DirectoryInfo] $path) {

        if ($path.FullName -eq (get-item $Global:AzOpsState).FullName) {
            #root tenant path
            $this.InitializeMemberVariables("/")
        }
        else {

            #Always look into .AzState folder regardless of path specified
            if (-not ($path.FullName.EndsWith('.azstate', "CurrentCultureIgnoreCase"))) {
                $path = Join-Path $path -ChildPath '.AzState'
            }
            $managementGroupFileName = "Microsoft.Management-managementGroups_*.parameters.json"
            $subscriptionFileName = "Microsoft.Subscription-subscriptions_*.parameters.json"
            $resourceGroupFileName = "Microsoft.Resources-resourceGroups_*.parameters.json"

            if (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $managementGroupFileName }) {
                $mg = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $managementGroupFileName }) | ConvertFrom-Json
                if ($mg.parameters.input.value.Id) {
                    $this.InitializeMemberVariables($mg.parameters.input.value.Id)
                }
                else {
                    Write-Error "$managementGroupFileName does not contain .parameters.input.value.Id"
                }
            }
            elseif (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $subscriptionFileName }) {
                $sub = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $subscriptionFileName }) | ConvertFrom-Json
                if ($sub.parameters.input.value.Id) {
                    $this.InitializeMemberVariables($sub.parameters.input.value.Id)
                }
                else {
                    Write-Error "Microsoft.Subscription-subscriptions* does not contain .parameters.input.value.Id"
                }
            }
            elseif (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $resourceGroupFileName }) {
                $rg = Get-Content (Get-ChildItem -Force  -path $path -File | Where-Object { $_.Name -like $resourceGroupFileName }) | ConvertFrom-Json
                if ($rg.parameters.input.value.ResourceId) {
                    $this.InitializeMemberVariables($rg.parameters.input.value.ResourceId)
                }
                else {
                    Write-Error "$resourceGroupFileName does not contain .parameters.input.value.ResourceId"
                }
            }
            else {
                Write-Error "Unable to determine AzOpsScope from $path"
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
            if ($Env:ExportRawTemplate -eq 1) {
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
            #$this.statepath = (join-path $this.FindAzOpsStatePath() -ChildPath "resourcegroup.json")
            if ($Env:ExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources-resourceGroups_$($this.resourcegroup).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsResourceGroupPath() -ChildPath ".AzState\Microsoft.Resources-resourceGroups_$($this.resourcegroup).parameters.json")
            }
        }
        elseif ($this.IsSubscription()) {
            $this.type = "subscriptions"
            $this.name = $this.IsSubscription()
            $this.subscription = $this.GetSubscription()
            $this.subscriptionDisplayName = $this.GetSubscriptionDisplayName()
            $this.managementgroup = $this.GetManagementGroup()
            $this.managementgroupDisplayName = $this.GetManagementGroupName()
            #$this.statepath = (join-path $this.FindAzOpsStatePath() -ChildPath "subscription.json")
            if ($Env:ExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription-subscriptions_$($this.subscription).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsSubscriptionPath() -ChildPath ".AzState\Microsoft.Subscription-subscriptions_$($this.subscription).parameters.json")
            }

        }
        elseif ($this.IsManagementGroup()) {
            $this.type = "managementGroups"
            $this.name = $this.GetManagementGroup()
            $this.managementgroup = ($this.GetManagementGroup()).Trim()
            $this.managementgroupDisplayName = ($this.GetManagementGroupName()).Trim()
            #$this.statepath = (join-path $this.FindAzOpsStatePath() -ChildPath "managementgroup.json")
            if ($Env:ExportRawTemplate -eq 1) {
                $this.statepath = (join-path $this.GetAzOpsManagementGroupPath($this.managementgroup) -ChildPath ".AzState\Microsoft.Management-managementGroups_$($this.managementgroup).json")
            }
            else {
                $this.statepath = (join-path $this.GetAzOpsManagementGroupPath($this.managementgroup) -ChildPath ".AzState\Microsoft.Management-managementGroups_$($this.managementgroup).parameters.json")
            }
        }
        elseif ($this.IsRoot()) {
            $this.type = "root"
            $this.name = "/"
            $this.statepath = $Global:AzOpsState
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
        #if ( ($this.scope.Split('/').count -eq 3) -and ($this.scope -imatch $this.regex_subscription)) {
        if ( ($this.scope -imatch $this.regex_subscription)) {
            return ( $this.scope.Split('/')[2])
        }
        return $null
    }
    [string] IsResourceGroup () {
        #if (($this.scope.Split('/').count -eq 5) -and ($this.scope -imatch $this.regex_resourceGroup)) {
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
            foreach ($mgmt in $Global:AzOpsAzManagementGroup) {
                if ($mgmt.DisplayName -eq $this.GetManagementGroupName()) {
                    return $mgmt.Name
                }
            }
        }
        if ($this.subscription) {
            foreach ($mgmt in $Global:AzOpsAzManagementGroup) {
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
        if (($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName })) {

            if (($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).parentId) {
                $parentPath = $this.GetAzOpsManagementGroupPath( (($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).parentId -split '/' | Select-Object -last 1))
                return (join-path $parentPath -ChildPath ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).DisplayName)
            }
            else {
                return  (join-path $global:AzOpsState -ChildPath ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupName }).DisplayName)
            }
        }
        else {
            Write-Error "ManagementGroup not found"
            return $null
        }
    }

    <#
        Should Return Management Group Display Name
    #>
    [string] GetManagementGroupName() {
        if ($this.scope -imatch $this.regex_managementgroupExtract) {
            $managementgroupID = ((($this.scope -split $this.regex_managementgroupExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)

            if ($managementgroupID) {

                Write-Verbose -Message " - Querying Global variable for AzOpsAzManagementGroup"
                if (($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupID }).DisplayName) {
                    return ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $managementgroupID }).DisplayName
                }
                else {
                    Write-Warning "Management group do not exist in Azure. Using Directory name as management group"
                    return  $managementgroupID
                }
            }
        }
        if ($this.subscription) {
            foreach ($mgmt in $Global:AzOpsAzManagementGroup) {
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

        return join-path $this.GetAzOpsManagementGroupPath($this.managementgroup)  -ChildPath $this.subscriptionDisplayName
    }
    [string] GetAzOpsResourceGroupPath() {

        return join-path $this.GetAzOpsSubscriptionPath()  -ChildPath $this.resourcegroup
    }
    [string] GetSubscription() {
        if ($this.scope -imatch $this.regex_subscriptionExtract) {

            $subId = ((($this.scope -split $this.regex_subscriptionExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)
            $sub = $global:AzOpsSubscriptions | Where-Object { $_.Id -eq $subId }
            if ($sub) {
                return $sub.Id
            }
            else {
                Write-Warning "Subscription do not exist in Azure. Defaulting to directory name for subscription"
                return $subId
            }
        }
        return $null
    }
    [string] GetSubscriptionDisplayName() {
        if ($this.scope -imatch $this.regex_subscriptionExtract) {

            $subId = ((($this.scope -split $this.regex_subscriptionExtract) -split '/') | Where-Object { $_ } | Select-Object -First 1)
            $sub = $global:AzOpsSubscriptions | Where-Object { $_.Id -eq $subId }
            if ($sub) {
                return $sub.Name
            }
            else {
                Write-Warning "Subscription do not exist in Azure. Defaulting to directory name for subscription"
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

        Write-Verbose -Message " - GetAzOpsResourcePath: $($this.scope)"
        if ($this.scope -imatch $this.regex_resourceGroupResource) {
            $rgpath = $this.GetAzOpsResourceGroupPath()

            #Checking if generated filename is valid otherwise switchign to MD5 hash as filename.
            if ( ($this.name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars() + '[' + ']') -eq -1 ) -and
                (Join-Path (Join-Path $rgpath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name)).Length -lt 250
            ) {
                return (Join-Path (Join-Path $rgpath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
            }
            else {
                #Windows has 256 character limit hence shorting the name by hashing the resource and name.
                $stream = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
                return (Join-Path (Join-Path $rgpath -ChildPath ".AzState") -ChildPath (Get-FileHash -InputStream $stream -Algorithm MD5).Hash)
            }
        }
        elseif ($this.scope -imatch $this.regex_subscriptionResource) {
            $subpath = $this.GetAzOpsSubscriptionPath()
            return (Join-Path (Join-path $subpath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
        }
        elseif ($this.scope -imatch $this.regex_managementgroupResource) {
            $mgmtPath = $this.GetAzOpsManagementGroupPath($this.managementgroup)
            return (Join-Path (Join-path $mgmtPath -ChildPath ".AzState") -ChildPath ($this.resourceprovider + "_" + $this.resource + "-" + $this.name))
        }
        Write-Error "Unable to determine Resource Scope"
        return $null
    }
}
<#
.SYNOPSIS
    Returns an AzOpsScope for a path or for a scope
.EXAMPLE
    #Return AzOpsScope for a root management group scope scope in Azure
    New-AzOpsScope -Scope "/providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560"
    scope                      : /providers/Microsoft.Management/managementGroups/3fc1081d-6105-4e19-b60c-1ec1252cf560
    type                       : managementGroups
    name                       : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    statepath                  : C:\git\cet-northstar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\.AzState\Microsoft.Management-managementGroups_3fc1081d-6105-4e19-b60c-1ec1252cf560.parame
                                ters.json
    managementgroup            : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    managementgroupDisplayName : 3fc1081d-6105-4e19-b60c-1ec1252cf560
    subscription               :
    subscriptionDisplayName    :
    resourcegroup              :
    resourceprovider           :
    resource                   :
.EXAMPLE
    #Return AzOpsScope for a filepath
    New-AzOpsScope -path  "C:\Users\jodahlbo\git\CET-NorthStar\azops\Tenant Root Group\Non-Production Subscriptions\Dalle MSDN MVP\365lab-dcs"
.INPUTS
    Scope
.INPUTS
    Path
.OUTPUTS
    [AzOpsScope]
#>
function New-AzOpsScope {
    [CmdletBinding()]
    param (
        #Scope
        [OutputType([AzOpsScope])]
        [Parameter(Position = 0, ParameterSetName = "scope", ValueFromPipeline = $true)]
        [string]$scope,
        #FilePath
        [Parameter(Position = 0, ParameterSetName = "pathfile", ValueFromPipeline = $true)]
        [string]$path
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Verify that required global variables are set
        Test-AzOpsVariables
        # $script = "Using module AzOps"
        # $script = [ScriptBlock]::Create($scriptBody)
        # . $script
        [regex]$regex_findAzStateFileExtension = '(?i)(.AzState)(|\\|\/)$'
    }
    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        #Return scope if scope was provided
        if ($PSCmdlet.ParameterSetName -eq "scope") {
            return [AzOpsScope]::new($scope)
        }
        #Get scope from filepath
        elseif ($PSCmdlet.ParameterSetName -eq "pathfile") {
            # Remove .AzState file extension if present
            $path = $path -replace $regex_findAzStateFileExtension, ''
            if ((Test-Path $path) -and (Test-Path $path -IsValid)) {
                return [AzOpsScope]::new($(Get-Item $path))
            }
        }
        else {
            Write-Warning "$path not found"
        }
    }
    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }
}

Export-ModuleMember -Function * -Alias *
