<#
This is the globl profile file for the Azure Function App.
This file will have been executed first, before any function runs.
Use this to create a common execution environment,
but keep in mind that the profile execution time is added to the function startup time for ALL functions.
#>

if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts))
{
	Connect-AzAccount -Identity
}