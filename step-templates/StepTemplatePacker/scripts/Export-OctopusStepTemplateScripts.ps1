function Export-OctopusStepTemplateScripts
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

    # export the scripts
    Export-OctopusStepTemplateScriptBody   -StepTemplate $StepTemplate -StepJson $stepJson;
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PreDeploy";
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "Deploy";
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PostDeploy";

}