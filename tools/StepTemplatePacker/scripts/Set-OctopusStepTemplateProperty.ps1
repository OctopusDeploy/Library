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

    $member = Get-Member -InputObject $StepJson -MemberType "NoteProperty" -Name "Properties";
    if( $member -eq $null )
    {
        Add-Member -InputObject $StepJson -NotePropertyName "Properties" -NotePropertyValue ([PSCustomObject] @{});
    }

    $member = Get-Member -InputObject $stepJson.Properties -MemberType "NoteProperty" -Name $PropertyName;
    if( $member -eq $null )
    {
        Add-Member -InputObject $StepJson.Properties -NotePropertyName $PropertyName -NotePropertyValue ([PSCustomObject] @{});
    }

    $StepJson.Properties.$PropertyName = $Value;

}