<#
.SYNOPSIS
    Recursively build/change management group hierarchy in file system from provided scope.
.DESCRIPTION
    Recursively build/change management group hierarchy in file system from provided scope.
.EXAMPLE
    #Discover management group hierarchy from scope
    Save-AzOpsManagementGroupChildren -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    management group hierarchy in file system
#>
function Save-AzOpsManagementGroupChildren {
    
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType()]
    param (
        #Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        [AzOpsScope]
        $scope
    )

    begin {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        #Ensure that required global variables are set.
        Test-AzOpsVariables
        Write-Verbose -Message " - Iterating over $($scope.name)"
    }

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        Write-Verbose "Processing Scope: $($scope.scope)"
        #Construct all file paths for scope
        $statepath = $scope.statepath
        $statepathFileName = [IO.Path]::GetFileName($scope.statepath)
        $statepathDirectory = [IO.Path]::GetDirectoryName($scope.statepath)
        $statepathScopeDirectory = [IO.Directory]::GetParent([IO.Path]::GetDirectoryName($scope.statepath))
        $statepathScopeDirectoryParent = [IO.Path]::GetFullPath([IO.Directory]::GetParent($statepathScopeDirectory))

        Write-Verbose -Message "StatePath is $($scope.statepath)"
        Write-Verbose -Message "StatePathFileName is $statepathFileName"
        Write-Verbose -Message "StatePathDirectory is $statepathDirectory"
        Write-Verbose -Message "StatePathScopeDirectory Directory is $statepathScopeDirectory"
        Write-Verbose -Message "StatePathScopeDirectoryParent Directory is $statepathScopeDirectoryParent"

        if (-not ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) {
            #If StatePathFilename do not exists inside AzOpsState, create one
            Write-Verbose -Message "New StatePath File will be created at $statepathFileName"
        }
        elseif (    ($null -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) -and 
                    ($statepathScopeDirectoryParent -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.Parent.FullName)
               )
        {
            #File Exists but parent is not the same, looking for Parent (.AzState) of a Parent to determine
            $exisitingScopePath = ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.FullName
            Write-Verbose -Message "StatePath File Exist at $exisitingScopePath"
            Write-Verbose -Message "Moving $exisitingScopePath to $statepathScopeDirectoryParent"
            Move-Item -Path $exisitingScopePath -Destination $statepathScopeDirectoryParent
        }

        #Ensure StatePathFile is always written with latest Config.Existence of file does not mean all information is up to date.
        if ($scope.type -eq 'managementGroups') {
            ConvertTo-AzOpsState -Resource ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }) -ExportPath $scope.statepath
            #Iterate through all child management groups recursively
            $ChildOfManagementGroups = ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }).Children
            if ($ChildOfManagementGroups) {
                $ChildOfManagementGroups | Foreach-Object {
                    $child = $_
                    Save-AzOpsManagementGroupChildren -scope (New-AzOpsScope -scope $child.id)
                }
            }
        }
        elseif ($scope.type -eq 'subscriptions') {
            #Export subscriptions to AzOpsState
            ConvertTo-AzOpsState -Resource (($global:AzOpsAzManagementGroup).children | Where-Object {$_ -ne $null -and $_.Name -eq $scope.name }) -ExportPath $scope.statepath
        }
    }

    end {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}