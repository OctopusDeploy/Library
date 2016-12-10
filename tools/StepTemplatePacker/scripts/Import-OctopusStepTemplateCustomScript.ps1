function Import-OctopusStepTemplateCustomScript
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $StepTemplate,

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson,

        [Parameter(Mandatory=$true)]
        [string] $ScriptName

    )

    # work out what file extension to use based on the language
    $filetype = Get-OctopusStepTemplateFileType -Syntax "PowerShell";

    # work out the filename for the script
    $stepFolder     = [System.IO.Path]::GetDirectoryName($StepTemplate);
    $scriptFilename = [System.IO.Path]::GetFileNameWithoutExtension($StepTemplate) + ".$ScriptName" + $fileType;
    $scriptPath     = [System.IO.Path]::Combine($stepFolder, $scriptFilename);

    # read the custom script in from disk
    if( -not [System.IO.File]::Exists($scriptPath) )
    {
        return;
    }
    else
    {
        $customScript = Get-OctopusTextFile -Path $scriptPath;
    }

    if( [string]::IsNullOrEmpty($customScript) )
    {
        return;
    }

    # update the step template
    Set-OctopusStepTemplateProperty -StepJson     $StepJson `
                                    -PropertyName "Octopus.Action.CustomScripts.$ScriptName.ps1" `
                                    -Value        $customScript;

}
