<#
    .SYNOPSIS
        New-DscClassResourceWikiPage generates wiki pages for class-based resources
        that can be uploaded to GitHub to use as public documentation for a module.

    .DESCRIPTION
        The New-DscClassResourceWikiPage cmdlet will review all of the class-based and
        in a specified module directory and will output the Markdown files to the
        specified directory. These help files include details on the property types
        for each resource, as well as a text description and examples where they exist.

    .PARAMETER OutputPath
        Where should the files be saved to.

    .PARAMETER SourcePath
        The path to the root of the DSC resource module (where the PSD1 file is found,
        not the folder for and individual DSC resource).

    .PARAMETER BuiltModulePath
        The path to the root of the built DSC resource module, e.g.
        'output/MyResource/1.0.0'.

    .PARAMETER Metadata
        Specifies metadata that is added to the markdown file.

    .PARAMETER Force
        Overwrites any existing file when outputting the generated content.

    .EXAMPLE
        New-DscClassResourceWikiPage `
            -SourcePath C:\repos\MyResource\source `
            -BuiltModulePath C:\repos\MyResource\output\MyResource\1.0.0 `
            -OutputPath C:\repos\MyResource\output\WikiContent

        This example shows how to generate wiki documentation for a specific module.

    .EXAMPLE
        New-DscClassResourceWikiPage `
            -SourcePath C:\repos\MyResource\source `
            -BuiltModulePath C:\repos\MyResource\output\MyResource\1.0.0 `
            -OutputPath C:\repos\MyResource\output\WikiContent `
            -Metadata @{
                Type = 'ClassResource'
                Category = 'Class-based resources'
            }

        This example shows how to generate wiki documentation for a specific module
        and passing in metadata for the markdown files.
#>
function New-DscClassResourceWikiPage
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $BuiltModulePath,

        [Parameter()]
        [System.Collections.Hashtable]
        $Metadata,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    if (Test-Path -Path $BuiltModulePath)
    {
        <#
            This must not use Recurse. Then it could potentially find resources
            that are part of common modules in the Modules folder.
        #>
        $getChildItemParameters = @{
            Path        = Join-Path -Path $BuiltModulePath -ChildPath '*'
            Include     = '*.psm1'
            ErrorAction = 'Stop'
            File        = $true
        }

        $builtModuleScriptFiles = Get-ChildItem @getChildItemParameters

        # Looping through each module file (normally just one).
        foreach ($builtModuleScriptFile in $builtModuleScriptFiles)
        {
            $dscResourceAsts = Get-ClassResourceAst -ScriptFile $builtModuleScriptFile.FullName

            Write-Verbose -Message ($script:localizedData.FoundClassBasedMessage -f $dscResourceAsts.Count, $builtModuleScriptFile.FullName)

            # Import module via 'using module'
            $scriptBody = ('using module {0}' -f $builtModuleScriptFile.FullName)
            $script = [scriptblock]::Create($scriptBody)
            . $script

            # Looping through each class-based resource.
            foreach ($dscResourceAst in $dscResourceAsts)
            {
                Write-Verbose -Message ($script:localizedData.GenerateWikiPageMessage -f $dscResourceAst.Name)

                $output = New-Object -TypeName 'System.Text.StringBuilder'

                # Add metadata to the top of the file.
                if ($Metadata)
                {
                    $null = $output.AppendLine('---')

                    foreach ($key in ($Metadata.Keys | Sort-Object))
                    {
                        $null = $output.AppendLine("$($key): $($Metadata.$key)")
                    }

                    $null = $output.AppendLine('---')
                    $null = $output.AppendLine()
                }

                # Add the documentation for the resource.
                $null = $output.AppendLine("# $($dscResourceAst.Name)")
                $null = $output.AppendLine()
                $null = $output.AppendLine('## Parameters')
                $null = $output.AppendLine()

                $sourceFilePath = Join-Path -Path $SourcePath -ChildPath ('Classes/*{0}.ps1' -f $dscResourceAst.Name)

                $scriptBody = ('[{0}]::new(); [{0}].GetProperties()' -f $dscResourceAst.Name)
                $cl = [scriptblock]::Create($scriptBody)
                [System.Reflection.PropertyInfo[]] $classProperties = $cl.InvokeReturnAsIs()

                $className = ($classProperties | Select-Object -Unique DeclaringType).DeclaringType

                # Returns the properties for class and any existing parent class(es).
                #$resourceProperty = Get-ClassResourceProperty -ClassName $className -SourcePath $SourcePath -BuiltModuleScriptFilePath $builtModuleScriptFile.FullName
                $resourceProperty = Get-ClassResourceProperty -ClassName $className -SourcePath $SourcePath -ClassProperties $classProperties

                $propertyContent = Get-DscResourceSchemaPropertyContent -Property $resourceProperty -UseMarkdown

                foreach ($line in $propertyContent)
                {
                    $null = $output.AppendLine($line)
                }

                $null = $output.AppendLine()

                $dscResourceCommentBasedHelp = Get-CommentBasedHelp -Path $sourceFilePath

                $description = $dscResourceCommentBasedHelp.Description
                $description = $description -replace '[\r|\n]+$' # Removes all blank rows and whitespace at the end

                $null = $output.AppendLine('## Description')
                $null = $output.AppendLine()
                $null = $output.AppendLine($description)
                $null = $output.AppendLine()

                $examplesPath = Join-Path -Path $SourcePath -ChildPath ('Examples\Resources\{0}' -f $dscResourceAst.Name)

                $examplesOutput = Get-ResourceExampleAsMarkdown -Path $examplesPath

                if ($examplesOutput.Length -gt 0)
                {
                    $null = $output.Append($examplesOutput)
                }

                $outputFileName = '{0}.md' -f $dscResourceAst.Name

                $savePath = Join-Path -Path $OutputPath -ChildPath $outputFileName

                Write-Verbose -Message ($script:localizedData.OutputWikiPageMessage -f $savePath)

                $outputToWrite = $output.ToString()
                $outputToWrite = $outputToWrite -replace '[\r|\n]+$' # Removes all blank rows and whitespace at the end
                $outputToWrite = $outputToWrite -replace '\r?\n', "`r`n" # Normalize to CRLF
                $outputToWrite = $outputToWrite -replace '[ ]+\r\n', "`r`n" # Remove indentation from blank rows

                $null = Out-File `
                    -InputObject $outputToWrite `
                    -FilePath $savePath `
                    -Encoding utf8 `
                    -Force:$Force
            }
        }
    }
}
