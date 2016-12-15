function Get-OctopusTextFile
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $Path

    )

    # wrapper around .Net class to support mocking in Pester

    return [System.IO.File]::ReadAllText($Path);

}