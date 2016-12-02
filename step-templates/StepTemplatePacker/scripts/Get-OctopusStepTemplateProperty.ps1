function Get-OctopusStepTemplateProperty
{

    param
    (

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson,
        [Parameter(Mandatory=$true)]
        [string] $PropertyName,
        [Parameter(Mandatory=$false)]
        [string] $DefaultValue = $null

    )

    $member = Get-Member -InputObject $StepJson.Properties -MemberType "NoteProperty" -Name $PropertyName;

    if( $member -eq $null )
    {
        return $DefaultValue;
    }
    else
    {
        return $StepJson.Properties.$PropertyName;
    }

}