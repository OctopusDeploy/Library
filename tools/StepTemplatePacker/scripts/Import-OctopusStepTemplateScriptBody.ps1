function Import-OctopusStepTemplateScriptBody
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

    # work out the filename for the script
    $stepFolder     = [System.IO.Path]::GetDirectoryName($StepTemplate);
    $scriptFilename = [System.IO.Path]::GetFileNameWithoutExtension($StepTemplate) + ".ScriptBody" + $fileType;
    $scriptPath     = [System.IO.Path]::Combine($stepFolder, $scriptFilename);

    # read the script body in from disk
    if( -not [System.IO.File]::Exists($scriptPath) )
    {
        return;
    }
    else
    {
        $scriptBody = Get-OctopusTextFile -Path $scriptPath;
    }

    if( [string]::IsNullOrEmpty($scriptBody) )
    {
        return;
    }

    # update the step template
    Set-OctopusStepTemplateProperty -StepJson     $StepJson `
                                    -PropertyName "Octopus.Action.Script.ScriptBody" `
                                    -Value        $scriptBody;

}
