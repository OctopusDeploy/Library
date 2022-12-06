function Get-OctopusStepTemplateFileType
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $Syntax

    )

    switch( $Syntax )
    {

        "PowerShell" {
            return ".ps1";
        }

        "Bash" {
            return ".sh";
        }

        "Python" {
            return ".py";
        }

        default {
            throw new-object System.NotImplementedException("Unhandled script syntax '$syntax'.");
        }

    }

}
