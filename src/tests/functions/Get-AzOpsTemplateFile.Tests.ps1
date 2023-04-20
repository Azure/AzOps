Describe "Function Test - Get-AzOpsTemplateFile" {

    BeforeAll {

    }

    Context "Test: SkipCustomJqTemplate true, only try built-in without fallback" {
        It 'Return built-in template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $true } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $true } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$jqTemplatePath/$template"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" }
                $returntemplate = Get-AzOpsTemplateFile -File $template
                $returntemplate | Should -Be "$jqTemplatePath/$template"
            }
        }
        It 'Throw when no template is identified' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $true } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $false }
                { Get-AzOpsTemplateFile -File $template } | Should -Throw
            }
        }
    }

    Context "Test: SkipCustomJqTemplate true, only try built-in with fallback" {
        It 'Return built-in template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                $fallbacktemplate = "generic.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $true } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $true } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$jqTemplatePath/$template"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" }
                $returntemplate = Get-AzOpsTemplateFile -File $template -Fallback $fallbacktemplate
                $returntemplate | Should -Be "$jqTemplatePath/$template"
            }
        }

        It 'Return built-in fallback template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                $fallbacktemplate = "generic.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $true } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$jqTemplatePath/$fallbacktemplate"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$jqTemplatePath/$fallbacktemplate" }
                $returntemplate = Get-AzOpsTemplateFile -File $template -Fallback $fallbacktemplate
                $returntemplate | Should -Be "$jqTemplatePath/$fallbacktemplate"
            }
        }
    }

    Context "Test: SkipCustomJqTemplate false without fallback" {
        It 'Return custom template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $false } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $true }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$customJqTemplatePath/$template"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$customJqTemplatePath/$template" }
                $returntemplate = Get-AzOpsTemplateFile -File $template
                $returntemplate | Should -Be "$customJqTemplatePath/$template"
            }
        }

        It 'Return built-in template, no custom file matching' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $false } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$customJqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Test-Path' -ModuleName AzOps { $true } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$jqTemplatePath/$template"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" }
                $returntemplate = Get-AzOpsTemplateFile -File $template
                $returntemplate | Should -Be "$jqTemplatePath/$template"
            }
        }
    }

    Context "Test: SkipCustomJqTemplate false with fallback" {
        It 'Return custom template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                $fallbacktemplate = "generic.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $false } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $true }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$customJqTemplatePath/$template"
                        }
                    }
                    return $object
                }
                $returntemplate = Get-AzOpsTemplateFile -File $template -Fallback $fallbacktemplate
                $returntemplate | Should -Be "$customJqTemplatePath/$template"
            }
        }

        It 'Return built-in template, no custom file matching' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                $fallbacktemplate = "generic.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $false } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$customJqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Test-Path' -ModuleName AzOps { $true } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$customJqTemplatePath/$template" }
                Mock 'Get-Item' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$customJqTemplatePath/$fallbacktemplate" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$jqTemplatePath/$template"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$jqTemplatePath/$template" }
                $returntemplate = Get-AzOpsTemplateFile -File $template -Fallback $fallbacktemplate
                $returntemplate | Should -Be "$jqTemplatePath/$template"
            }
        }

        It 'Return custom fallback template' {
            InModuleScope AzOps {
                $jqTemplatePath = "AzOps/src/data/template"
                $customJqTemplatePath = "AzOps/.customtemplates"
                $template = "templateChildResource.jq"
                $fallbacktemplate = "generic.jq"
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $jqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.JqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { return $customJqTemplatePath } -ParameterFilter { $FullName -eq "AzOps.Core.CustomJqTemplatePath" }
                Mock 'Get-PSFConfigValue' -ModuleName AzOps { $false } -ParameterFilter { $FullName -eq "AzOps.Core.SkipCustomJqTemplate" }
                Mock 'Test-Path' -ModuleName AzOps { $false } -ParameterFilter { $Path -eq "$customJqTemplatePath/$template" -and $PathType -eq "Leaf" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$customJqTemplatePath/$jqTemplatePath"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$customJqTemplatePath/$jqTemplatePath" }
                Mock 'Get-Item' -ModuleName AzOps {
                    $object = [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileName = "$customJqTemplatePath/$fallbacktemplate"
                        }
                    }
                    return $object
                } -ParameterFilter { $Path -eq "$customJqTemplatePath/$fallbacktemplate" }
                $returntemplate = Get-AzOpsTemplateFile -File $template -Fallback $fallbacktemplate
                $returntemplate | Should -Be "$customJqTemplatePath/$fallbacktemplate"
            }
        }
    }

    AfterAll {

    }

}