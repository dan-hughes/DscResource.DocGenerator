#region HEADER
$script:projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$script:projectName = (Get-ChildItem -Path "$script:projectPath\*\*.psd1" | Where-Object -FilterScript {
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try
            {
                Test-ModuleManifest -Path $_.FullName -ErrorAction Stop
            }
            catch
            {
                $false
            })
    }).BaseName

$script:moduleName = Get-Module -Name $script:projectName -ListAvailable | Select-Object -First 1
Remove-Module -Name $script:moduleName -Force -ErrorAction 'SilentlyContinue'

Import-Module $script:moduleName -Force -ErrorAction 'Stop'
#endregion HEADER

InModuleScope $script:moduleName {
    Describe 'ConvertTo-WikiSidebarLinkName' {
        Context 'When converting a simple hyphenated name' {
            BeforeAll {
                if ($PSVersionTable.PSVersion -ge '6.0')
                {
                    $mockExpectedResult = 'My Page Name'
                }
                else
                {
                    $mockExpectedResult = 'My-Page-Name'
                }
            }

            It 'Should replace hyphens with spaces' {
                $result = ConvertTo-WikiSidebarLinkName -Name 'My-Page-Name'
                $result | Should -Be $mockExpectedResult
            }
        }

        Context 'When converting a name with Unicode hyphens' {
            BeforeAll {
                if ($PSVersionTable.PSVersion -ge '6.0')
                {
                    $mockExpectedResult = 'Unicode-Hyphen'
                }
                else
                {
                    $mockExpectedResult = 'Unicode{0}Hyphen' -f [System.Char]::ConvertFromUtf32(0x2011)
                }
            }

            It 'Should replace Unicode hyphens with standard hyphens' {
                $result = ConvertTo-WikiSidebarLinkName -Name ('Unicode{0}Hyphen' -f [System.Char]::ConvertFromUtf32(0x2011))  # Note: The hyphen here is a Unicode hyphen (U+2010)
                $result | Should -Be $mockExpectedResult
            }
        }

        Context 'When the input is piped' {
            BeforeAll {
                if ($PSVersionTable.PSVersion -ge '6.0')
                {
                    $mockExpectedResult = 'Piped Input'
                }
                else
                {
                    $mockExpectedResult = 'Piped-Input'
                }
            }

            It 'Should process the piped input correctly' {
                'Piped-Input' | ConvertTo-WikiSidebarLinkName | Should -Be $mockExpectedResult
            }
        }

        Context 'When the input contains multiple types of hyphens' {
            BeforeAll {
                if ($PSVersionTable.PSVersion -ge '6.0')
                {
                    $mockExpectedResult = 'Multiple-Hyphens Here'
                }
                else
                {
                    $mockExpectedResult = 'Multiple{0}Hyphens-Here' -f [System.Char]::ConvertFromUtf32(0x2011)
                }
            }

            It 'Should replace all hyphens appropriately' {
                $result = ConvertTo-WikiSidebarLinkName -Name ('Multiple{0}Hyphens-Here' -f [System.Char]::ConvertFromUtf32(0x2011))  # Contains both Unicode and standard hyphens
                $result | Should -Be $mockExpectedResult
            }
        }

        Context 'When the input does not contain hyphens' {
            It 'Should return the input unchanged' {
                $result = ConvertTo-WikiSidebarLinkName -Name 'NoHyphensHere'
                $result | Should -Be 'NoHyphensHere'
            }
        }
    }
}
