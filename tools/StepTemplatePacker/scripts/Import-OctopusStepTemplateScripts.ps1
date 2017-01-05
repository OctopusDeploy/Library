function Import-OctopusStepTemplateScripts
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $StepTemplate

    )

    $ErrorActionPreference = "Stop";
    Set-StrictMode -Version "Latest";

    # read and parse the step template's json
    $stepText = [System.IO.File]::ReadAllText($StepTemplate);
    $stepJson = ConvertFrom-Json -InputObject $stepText;

    # import the scripts
    Import-OctopusStepTemplateScriptBody   -StepTemplate $StepTemplate -StepJson $stepJson;
    Import-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PreDeploy";
    Import-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "Deploy";
    Import-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PostDeploy";

    $stepText = ConvertTo-OctopusJson -InputObject $stepJson;
    Set-OctopusTextFile -Path     $StepTemplate `
                        -Contents $stepText;

}