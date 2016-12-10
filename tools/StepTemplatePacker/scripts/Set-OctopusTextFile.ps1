function Set-OctopusTextFile
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $Path,

        [Parameter(Mandatory=$true)]
        [string] $Contents

    )

    # wrapper around .Net class to support mocking in Pester

    [System.IO.File]::WriteAllText($Path, $Contents);

}