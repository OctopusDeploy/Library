function Export-OctopusStepTemplateCustomScript
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $StepTemplate,

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson,

        [Parameter(Mandatory=$true)]
        [string] $ScriptName,

        [Parameter(Mandatory=$false)]
        [switch] $Force = $false

    )

    # work out what file extension to use based on the language
    $filetype = Get-OctopusStepTemplateFileType -Syntax "PowerShell";

    # extract the custom script
    $customScript = Get-OctopusStepTemplateProperty -StepJson     $StepJson `
                                                    -PropertyName "Octopus.Action.CustomScripts.$ScriptName.ps1";
    if( [string]::IsNullOrEmpty($customScript) )
    {
        return;
    }

    # work out the filename for the script
    $stepFolder     = [System.IO.Path]::GetDirectoryName($StepTemplate);
    $scriptFilename = [System.IO.Path]::GetFileNameWithoutExtension($StepTemplate) + ".$ScriptName" + $fileType;
    $scriptPath     = [System.IO.Path]::Combine($stepFolder, $scriptFilename);

    # check if the file already exists and whether to overwrite
    if( [System.IO.File]::Exists($scriptPath) -and -not $Force )
    {
        return;
    }

    # write the custom script out to disk
    Set-OctopusTextFile -Path     $scriptPath `
                        -Contents $customScript;

}
