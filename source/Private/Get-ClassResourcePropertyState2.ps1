<#
    .SYNOPSIS
        This function returns the property state value of an class-based DSC
        resource property.

    .DESCRIPTION
        This function returns the property state value of an DSC class-based
        resource property.

    .PARAMETER Ast
        The Abstract Syntax Tree (AST) for class-based DSC resource property.
        The passed value must be an AST of the type 'PropertyMemberAst'.

    .EXAMPLE
        Get-ClassResourcePropertyState -Ast {
            [DscResource()]
            class NameOfResource {
                [DscProperty(Key)]
                [string] $KeyName

                [NameOfResource] Get() {
                    return $this
                }

                [void] Set() {}

                [bool] Test() {
                    return $true
                }
            }
        }.Ast.Find({$args[0] -is [System.Management.Automation.Language.PropertyMemberAst]}, $false)

        Returns the property state for the property 'KeyName'.
#>
function Get-ClassResourcePropertyState
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Reflection.PropertyInfo]
        $PropertyInfo
    )

    <#
        Check for Key first since it it possible to use both Key and Mandatory
        on a property and in that case we want to return just 'Key'.
    #>

    if (($PropertyInfo | Where-Object { $_.CustomAttributes.NamedArguments.MemberName -eq 'Key' -and $_.CustomAttributes.NamedArguments.TypedValue.Value -eq $true }))
    {
        $propertyState = 'Key'
    }
    elseif (($PropertyInfo | Where-Object { $_.CustomAttributes.NamedArguments.MemberName -eq 'Mandatory' -and $_.CustomAttributes.NamedArguments.TypedValue.Value -eq $true }))
    {
        $propertyState = 'Required'
    }
    elseif (($PropertyInfo | Where-Object { $_.CustomAttributes.NamedArguments.MemberName -eq 'NotConfigurable' -and $_.CustomAttributes.NamedArguments.TypedValue.Value -eq $true }))
    {
        $propertyState = 'Read'
    }
    elseif (($PropertyInfo | Where-Object { $null -eq $_.CustomAttributes.NamedArguments.MemberName }))
    {
        $propertyState = 'Write'
    }

    return $propertyState
}
