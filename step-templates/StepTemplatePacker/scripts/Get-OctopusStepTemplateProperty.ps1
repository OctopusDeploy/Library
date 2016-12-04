function Get-OctopusStepTemplateProperty
{

    param
    (

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson,

        [Parameter(Mandatory=$true)]
        [string] $PropertyName,

        [Parameter(Mandatory=$false)]
        [string] $DefaultValue = [string]::Empty

    )

    $member = Get-Member -InputObject $StepJson -MemberType "NoteProperty" -Name "Properties";
    if( $member -eq $null )
    {
        return $DefaultValue;
    }

    $member = Get-Member -InputObject $StepJson.Properties -MemberType "NoteProperty" -Name $PropertyName;
    if( $member -eq $null )
    {
        return $DefaultValue;
    }

    return $StepJson.Properties.$PropertyName;

}