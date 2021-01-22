$script:ModuleRoot = $PSScriptRoot

foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\internal\configurations" -Recurse -Filter '*.ps1'))
{
	. $file.FullName
}
foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\internal\functions" -Recurse -Filter '*.ps1'))
{
	. $file.FullName
}
foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\functions" -Recurse -Filter '*.ps1'))
{
	. $file.FullName
}