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

    # The following SuppressMessageAttribute entries are used to surpress
    # PSScriptAnalyzer tests against known exceptions as per:
    # https://github.com/powershell/psscriptanalyzer#suppressing-rules
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'global:AzOpsAzManagementGroup')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType()]
    param (
        # Scope to discover - assumes [AzOpsScope] object
        [Parameter(Mandatory = $true)]
        $scope
    )

    begin {
        Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message ("Initiating function " + $MyInvocation.MyCommand + " begin")
    }

    process {
        Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message ("Initiating function " + $MyInvocation.MyCommand + " process")
        # Create new AzOpsScope object type from input scope objects
        $scope = (New-AzOpsScope -scope $scope -ErrorAction SilentlyContinue)

        # Continue if scope exists (added since management group api returns disabled/inaccesible subscriptions)
        if ($scope) {
            Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Processing Scope: $($scope.scope)"
            # Construct all file paths for scope
            $statepath = $scope.statepath
            $statepathFileName = [IO.Path]::GetFileName($statepath)
            $statepathDirectory = [IO.Path]::GetDirectoryName($statepath)
            $statepathScopeDirectory = [IO.Directory]::GetParent($statepathDirectory).ToString()
            $statepathScopeDirectoryParent = [IO.Directory]::GetParent($statepathScopeDirectory).ToString()

            Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message "StatePath is $($statepath)"
            Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message "StatePathFileName is $statepathFileName"
            Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message "StatePathDirectory is $statepathDirectory"
            Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message "StatePathScopeDirectory Directory is $statepathScopeDirectory"
            Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message "StatePathScopeDirectoryParent Directory is $statepathScopeDirectoryParent"

            if (-not ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) {
                # If StatePathFilename do not exists inside AzOpsState, create one
                Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Creating new state file: $statepathFileName"
            }
            elseif (($null -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName })) -and
                ($statepathScopeDirectoryParent -ne ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.Parent.FullName)) {
                # File Exists but parent is not the same, looking for Parent (.AzState) of a Parent to determine
                $exisitingScopePath = ((Get-ChildItem -Path $AzOpsState -File -Recurse -Force) | Where-Object -FilterScript { $_.Name -eq $statepathFileName }).Directory.Parent.FullName
                Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Found existing state file in directory: $exisitingScopePath"
                Move-Item -Path $exisitingScopePath -Destination $statepathScopeDirectoryParent
                Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Moved existing state file to: $statepathScopeDirectoryParent"
            }

            # Ensure StatePathFile is always written with latest Config.Existence of file does not mean all information is up to date.
            if ($scope.type -eq 'managementGroups') {
                ConvertTo-AzOpsState -Resource ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }) -ExportPath $scope.statepath
                # Iterate through all child Management Groups recursively
                $ChildOfManagementGroups = ($global:AzOpsAzManagementGroup | Where-Object { $_.Name -eq $scope.managementgroup }).Children
                if ($ChildOfManagementGroups) {
                    $ChildOfManagementGroups | Foreach-Object {
                        $child = $_
                        Save-AzOpsManagementGroupChildren -scope $child.id
                    }
                }
            }
            elseif ($scope.type -eq 'subscriptions') {
                # Export subscriptions to AzOpsState
                ConvertTo-AzOpsState -Resource (($global:AzOpsAzManagementGroup).children | Where-Object { $_ -ne $null -and $_.Name -eq $scope.name }) -ExportPath $scope.statepath
            }
        }
        else {
            Write-AzOpsLog -Level Verbose -Topic "Save-AzOpsManagementGroupChildren" -Message "Scope [$($PSBoundParameters['Scope'])] not found in Azure or it is excluded"
        }
    }

    end {
        Write-AzOpsLog -Level Debug -Topic "Save-AzOpsManagementGroupChildren" -Message ("Initiating function " + $MyInvocation.MyCommand + " end")
    }

}