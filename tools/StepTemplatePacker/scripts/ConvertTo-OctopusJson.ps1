function ConvertTo-OctopusJson
{

    param
    (

        [Parameter(Mandatory=$false)]
        [object] $Inputobject,

        [Parameter(Mandatory=$false)]
        [string] $Indent = [string]::Empty

    )

    $ErrorActionPreference = "Stop";
    Set-StrictMode -Version "Latest";

    if( $InputObject -eq $null )
    {
        return "null";
    }

    switch( $true )
    {

        { $InputObject -is [string] } {
            $value = $InputObject;
            $value = $value.Replace("\",  "\\");
            $value = $value.Replace("`"", "\`"");
            $value = $value.Replace("`r", "\r");
            $value = $value.Replace("`n", "\n");
            $value = $value.Replace("`t", "\t");
            return "`"$value`"";
        }

        { $InputObject -is [int32] } {
            return $InputObject.ToString();
        }

        { $InputObject -is [System.Int64] } {
            return $InputObject.ToString();
        }

        { $InputObject -is [System.DateTime] } {
            return "`"$($InputObject.ToString("O"))`"";
        }

        { $InputObject -is [Array] } {
            $json = new-object System.Text.StringBuilder;
            $items = $InputObject;
            if( $items.Length -eq 0 )
            {
                [void] $json.Append("[]");
            }
            else
            {
                [void] $json.AppendLine("[");
                for( $i = 0; $i -lt $items.Length; $i++ )
                {
                    $itemJson = ConvertTo-OctopusJson -InputObject $items[$i] -Indent ($Indent + "  ");
                    [void] $json.Append("$Indent  $itemJson");
                    if( $i -lt ($items.Length - 1) )
                    {
                        [void] $json.Append(",");
                    }
                    [void] $json.AppendLine();
                }
                [void] $json.Append("$Indent]");
            }
            return $json.ToString();
        }

        { $InputObject -is [PSCustomObject] } {
            $json = new-object System.Text.StringBuilder;
            $properties = @( $InputObject.psobject.Properties );
            if( $properties.Length -eq 0 )
            {
                [void] $json.Append("{}");
            }
            else
            {
                [void] $json.AppendLine("{");
                for( $i = 0; $i -lt $properties.Length; $i++ )
                {
                    $property = $properties[$i];
                    $propertyJson = ConvertTo-OctopusJson -InputObject $property.Value -Indent ($Indent + "  ");
                    [void] $json.Append("$Indent  `"$($property.Name)`": $propertyJson");
                    if( $i -lt ($properties.Length - 1) )
                    {
                        [void] $json.Append(",");
                    }
                    [void] $json.AppendLine();
                }
                [void] $json.Append("$Indent}");
            }
            return $json.ToString();
        }

        default {
            $typename = $InputObject.GetType().FullName;
            throw new-object System.InvalidOperationException("Unhandled input object type '$typename'.");
        }

    }

}