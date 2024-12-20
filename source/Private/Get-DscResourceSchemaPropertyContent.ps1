<#
    .SYNOPSIS
        Get-DscResourceSchemaPropertyContent is used to generate the parameter content
        for the wiki page.

    .DESCRIPTION
        Get-DscResourceSchemaPropertyContent is used to generate the parameter content
        for the wiki page.

    .PARAMETER Property
        A hash table with properties that is returned by Get-MofSchemaObject in
        the property Attributes.

    .PARAMETER UseMarkdown
        If certain text should be output as markdown, for example values of the
        hashtable property ValueMap.

    .EXAMPLE
        $content = Get-DscResourceSchemaPropertyContent -Property @(
                @{
                    Name             = 'StringProperty'
                    DataType         = 'String'
                    IsArray          = $false
                    State            = 'Key'
                    Description      = 'Any description'
                    EmbeddedInstance = $null
                    ValueMap         = $null
                }
            )

        Returns the parameter content based on the passed array of parameter metadata.
#>
function Get-DscResourceSchemaPropertyContent
{
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable[]]
        $Property,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $UseMarkdown
    )

    $stringArray = [System.String[]] @()

    $stringArray += '| Parameter | Attribute | DataType | Description | Allowed Values |'
    $stringArray += '| --- | --- | --- | --- | --- |'

    # Order the properties
    $orderedProperties = @()
    $sortOrder = @(
        'Key'
        'Required'
        'Write'
        'Read'
    )

    foreach ($key in $sortOrder)
    {
        $orderedProperties += $Property.GetEnumerator() | Where-Object { $_.State -eq $key } | Sort-Object { $_.Name }
    }

    foreach ($currentProperty in $orderedProperties)
    {
        if ($currentProperty.EmbeddedInstance -eq 'MSFT_Credential')
        {
            $dataType = 'PSCredential'
        }
        elseif (-not [System.String]::IsNullOrEmpty($currentProperty.EmbeddedInstance))
        {
            $dataType = $currentProperty.EmbeddedInstance
        }
        else
        {
            $dataType = $currentProperty.DataType
        }

        # If the attribute is an array, add [] to the DataType string.
        if ($currentProperty.IsArray)
        {
            $dataType = $dataType.ToString() + '[]'
        }

        $propertyLine = "| **$($currentProperty.Name)** " + `
            "| $($currentProperty.State) " + `
            "| $dataType |"

        if (-not [System.String]::IsNullOrEmpty($currentProperty.Description))
        {
            $propertyLine += ' ' + $currentProperty.Description
        }

        $propertyLine += ' |'

        if (-not [System.String]::IsNullOrEmpty($currentProperty.ValueMap))
        {
            $valueMap = $currentProperty.ValueMap

            if ($UseMarkdown.IsPresent)
            {
                $valueMap = $valueMap | ForEach-Object -Process {
                    '`{0}`' -f $_
                }
            }

            $propertyLine += ' ' + ($valueMap -join ', ')
        }

        $propertyLine += ' |'

        $stringArray += $propertyLine
    }

    return (, $stringArray)
}
