function Set-OctopusStepTemplateProperty
{

    param
    (

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson,
        [Parameter(Mandatory=$true)]
        [string] $PropertyName,
        [Parameter(Mandatory=$false)]
        [object] $Value = $null

    )

    $member = Get-Member -InputObject $stepJson.Properties -MemberType "NoteProperty" -Name $PropertyName;

    if( $member -eq $null )
    {
write-host "aaa"
        return;
    }

    $StepJson.Properties.$PropertyName = $Value;

}