<#
.SYNOPSIS
    Resource provider features registration until ARM support is available.
.DESCRIPTION
    Resource provider features registration until ARM support is available.  Following format is used for *.resourceproviders.json
        [
            {
                "FeatureName":  "",
                "ProviderName":  "",
                "RegistrationState":  ""
            }
        ]
.EXAMPLE
    #Invoke resource providers registration
    Register-AzOpsResourceProvider -filename 'C:\Git\CET-NorthStar\azops\3fc1081d-6105-4e19-b60c-1ec1252cf560\contoso\platform\connectivity\resourceproviders.json'
.INPUTS
    Filename
    Scope
.OUTPUTS
    None
#>
function Register-AzOpsResourceProvider {

    [CmdletBinding()]
    param (
        [Parameter()]
        $filename,
        [Parameter()]
        $scope
    )

    begin {}

    process {
        Write-Verbose -Message ("Initiating function " + $MyInvocation.MyCommand + " process")

        if ( ($scope.subscription) -and (Get-AzContext).Subscription.Id -ne $scope.subscription) {
            Write-Verbose "Switching Subscription context from $($(Get-AzContext).Subscription.Name) to $scope.subscription "
            Set-AzContext -SubscriptionId $scope.subscription
        }

        $resourceproviders = (get-Content  $filename | ConvertFrom-Json)
        foreach ($resourceprovider  in $resourceproviders | Where-Object -FilterScript { $_.RegistrationState -eq 'Registered' }  ) {
            if ($resourceprovider.ProviderNamespace) {

                Write-Verbose "Registering Provider $($prvoviderfeature.ProviderNamespace)"

                Register-AzResourceProvider -Confirm:$false -pre -ProviderNamespace $resourceprovider.ProviderNamespace
            }

        }
    }

    end {}

}