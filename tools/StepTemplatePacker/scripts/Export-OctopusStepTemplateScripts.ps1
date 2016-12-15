function Export-OctopusStepTemplateScripts
{

    param
    (

        [Parameter(Mandatory=$true)]
        [string] $StepTemplate,

        [Parameter(Mandatory=$false)]
        [switch] $Force = $false

    )

    $ErrorActionPreference = "Stop";
    Set-StrictMode -Version "Latest";

    # read and parse the step template's json
    $stepText = Get-OctopusTextFile -Path $StepTemplate;
    $stepJson = ConvertFrom-Json -InputObject $stepText;

    # export the scripts
    Export-OctopusStepTemplateScriptBody   -StepTemplate $StepTemplate -StepJson $stepJson -Force:$Force;
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PreDeploy"  -Force:$Force;
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "Deploy"     -Force:$Force;
    Export-OctopusStepTemplateCustomScript -StepTemplate $StepTemplate -StepJson $stepJson -ScriptName "PostDeploy" -Force:$Force;

}