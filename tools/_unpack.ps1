param
(

    [Parameter(Mandatory=$false)]
    [string] $SearchPattern,

    [Parameter(Mandatory=$false)]
    [switch] $Force = $false

)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript  = $MyInvocation.MyCommand.Path;
$thisFolder  = [System.IO.Path]::GetDirectoryName($thisScript);

Import-Module -Name ([System.IO.Path]::Combine($thisFolder, "StepTemplatePacker")) -ErrorAction "Stop";

$stepTemplateFolder = $thisFolder;
$stepTemplateFolder = [System.IO.Path]::GetDirectoryName($stepTemplateFolder);
$stepTemplateFolder = [System.IO.Path]::Combine($stepTemplateFolder, "step-templates");

if( $PSBoundParameters.ContainsKey("SearchPattern") )
{
    $stepTemplates = [System.IO.Directory]::GetFiles($stepTemplateFolder, "$SearchPattern.json");
}
else
{
    $stepTemplates = [System.IO.Directory]::GetFiles($stepTemplateFolder, "*.json");
}

foreach( $stepTemplate in $stepTemplates )
{
    write-host "unpacking '$([System.IO.Path]::GetFileName($stepTemplate))'";
    Export-OctopusStepTemplateScripts -StepTemplate $stepTemplate -Force:$Force;
}