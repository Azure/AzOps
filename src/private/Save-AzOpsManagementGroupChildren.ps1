<#
.SYNOPSIS
    Recursively build/change Management Group hierarchy in file system from provided scope.
.DESCRIPTION
    Recursively build/change Management Group hierarchy in file system from provided scope.
.EXAMPLE
    # Discover Management Group hierarchy from scope
    Save-AzOpsManagementGroupChildren -scope (New-AzOpsScope -scope /providers/Microsoft.Management/managementGroups/contoso)
.INPUTS
    AzOpsScope
.OUTPUTS
    Management Group hierarchy in file system
#>
function Save-AzOpsManagementGroupChildren {

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType()]
    param (
        # Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
        # Ensure that required global variables are set.
        Test-AzOpsVariables
    }

    process {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        # Create new AzOpsScope object type from input scope object
        $scope = (New-AzOpsScope -scope $scope)
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Processing Scope: $($scope.scope)"
        # Construct all file paths for scope
        $statepath = $scope.statepath
        $statepathFileName = [IO.Path]::GetFileName($scope.statepath)
        $statepathDirectory = [IO.Path]::GetDirectoryName($scope.statepath)
        $statepathScopeDirectory = [IO.Directory]::GetParent([IO.Path]::GetDirectoryName($scope.statepath))
        $statepathScopeDirectoryParent = [IO.Path]::GetFullPath([IO.Directory]::GetParent($statepathScopeDirectory))

        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePath is $($scope.statepath)"
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePathFileName is $statepathFileName"
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePathDirectory is $statepathDirectory"
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePathScopeDirectory Directory is $statepathScopeDirectory"
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePathScopeDirectoryParent Directory is $statepathScopeDirectoryParent"

        if (-not ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) {
            # If StatePathFilename do not exists inside AzOpsState, create one
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "New StatePath File will be created at $statepathFileName"
        }
        elseif (    ($null -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) -and 
                    ($statepathScopeDirectoryParent -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.Parent.FullName)
               )
        {
            # File Exists but parent is not the same, looking for Parent (.AzState) of a Parent to determine
            $exisitingScopePath = ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.FullName
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "StatePath File Exist at $exisitingScopePath"
            Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message "Moving $exisitingScopePath to $statepathScopeDirectoryParent"
            Move-Item -Path $exisitingScopePath -Destination $statepathScopeDirectoryParent
        }

        # Ensure StatePathFile is always written with latest Config.Existence of file does not mean all information is up to date.
        if ($scope.type -eq 'managementGroups') {
            ConvertTo-AzOpsState -Resource ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }) -ExportPath $scope.statepath
            # Iterate through all child Management Groups recursively
            $ChildOfManagementGroups = ($Global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }).Children
            if ($ChildOfManagementGroups) {
                $ChildOfManagementGroups | Foreach-Object {
                    $child = $_
                    Save-AzOpsManagementGroupChildren -scope $child.id
                }
            }
        }
        elseif ($scope.type -eq 'subscriptions') {
            # Export subscriptions to AzOpsState
            ConvertTo-AzOpsState -Resource (($global:AzOpsAzManagementGroup).children | Where-Object {$_ -ne $null -and $_.Name -eq $scope.name }) -ExportPath $scope.statepath
        }
    }

    end {
        Write-AzOpsLog -Level Verbose -Topic "pwsh" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}