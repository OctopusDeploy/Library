function Export-OctopusStepTemplateScriptBody
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $StepTemplate,

        [Parameter(Mandatory=$true)]
        [PsCustomObject] $StepJson

    )

    # check this is an inline script, otherwise there's nothing to expand
    $scriptSource = Get-OctopusStepTemplateProperty -StepJson     $StepJson `
                                                    -PropertyName "Octopus.Action.Script.ScriptSource" `
                                                    -DefaultValue "Inline";
    if( $scriptSource -ne "Inline" )
    {
        return;
    }

    # work out what file extension to use based on the language
    $syntax = Get-OctopusStepTemplateProperty -StepJson     $StepJson `
                                              -PropertyName "Octopus.Action.Script.Syntax" `
                                              -DefaultValue "PowerShell";
    $filetype = Get-OctopusStepTemplateFileType -Syntax $syntax;

    # extract the script body text
    $scriptBody = Get-OctopusStepTemplateProperty -StepJson     $StepJson `
                                                  -PropertyName "Octopus.Action.Script.ScriptBody";
    if( [string]::IsNullOrEmpty($scriptBody) )
    {
        return;
    }

    # work out the filename for the script
    $stepFolder     = [System.IO.Path]::GetDirectoryName($StepTemplate);
    $scriptFilename = [System.IO.Path]::GetFileNameWithoutExtension($StepTemplate) + ".ScriptBody" + $fileType;
    $scriptPath     = [System.IO.Path]::Combine($stepFolder, $scriptFilename);

    # write the script body out to disk
    [System.IO.File]::WriteAllText($scriptPath, $scriptBody);

}
