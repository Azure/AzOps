<#
.SYNOPSIS
    Resource providers registration until ARM support is available
.DESCRIPTION
    This cmdlet invokes following imperative operations that are not supported in ARM.
    1) Resource providers registration until ARM support is available.  Following format is used for *.providerfeatures.json 
        [
            {
                "ProviderNamespace":  "Microsoft.Security",
                "RegistrationState":  "Registered"
            }
        ]
.EXAMPLE
    #Invoke provider features registration
    Register-AzOpsProviderFeature -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\platform\connectivity\providerfeatures.json'
.INPUTS
    Filename
    Scope
.OUTPUTS
    None
#>
function Register-AzOpsProviderFeature {

    [CmdletBinding()]
    param (
        [Parameter()]
        $filename,
        [Parameter()]
        $scope
    )

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        if ($scope.Subscription -match ".") {
            #Get subscription id from scope (since subscription id is not available for resource groups and resources)
            if (($scope.subscription) -and $CurrentAzContext.Subscription.Id -ne $scop.subscription) {
                Write-Verbose -Message " - Switching Subscription context from $($CurrentAzContext.Subscription.Name)/$($CurrentAzContext.Subscription.Id) to $($scope.subscription)/$($scope.name) "
                try {
                    Set-AzContext -SubscriptionId $scope.subscription -ErrorAction Stop | Out-Null
                }
                catch {
                    throw "Couldn't switch context $_"
                }
            }
        }

        $ProviderFeatures = (get-Content  $filename | ConvertFrom-Json)
        foreach ($ProviderFeature in $ProviderFeatures) {
            if ($ProviderFeature.FeatureName -and $ProviderFeature.ProviderName ) {
                Write-Verbose "Registering Feature $($ProviderFeature.FeatureName) in Provider $($ProviderFeature.ProviderName) namespace"
                Register-AzProviderFeature -Confirm:$false -ProviderNamespace $ProviderFeature.ProviderName -FeatureName $ProviderFeature.FeatureName
            }
        }
    }

}