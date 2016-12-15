[CmdletBinding()]
param
(
    [Parameter(Mandatory=$false)]
    [string] $SearchPattern,
    [Parameter(Mandatory=$false)]
    $Operation = 'unpack'
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version "Latest"

$thisScript  = $MyInvocation.MyCommand.Path;
Write-Verbose "`$thisScript $thisScript"
$thisFolder  = Split-Path -parent $thisScript
Write-Verbose "`$thisFolder $thisFolder"
Import-Module -Name (Join-Path $thisFolder "StepTemplatePacker") -ErrorAction "Stop";

$parentFolder = Split-Path -parent $thisFolder
Write-Verbose "`$parentFolder $parentFolder"
$stepTemplateFolder = Join-Path $parentFolder "step-templates"
Write-Verbose "`$stepTemplateFolder $stepTemplateFolder"

if( $PSBoundParameters.ContainsKey("SearchPattern") )
{
    $stepTemplates = Get-ChildItem $stepTemplateFolder -Filter "$SearchPattern.json"
    if (!($stepTemplates)) { "No templates found matching $SearchPattern, maybe try using a wildcard *$SearchPattern*" }
    Write-Debug "$stepTemplates"
}
else
{
    $stepTemplates = Get-ChildItem $stepTemplateFolder -Filter "*.json"
    Write-Debug "$stepTemplates"
}

switch ($Operation)
{
    "unpack" {
    function Run-Command ($stepTemplate)
        {
        write-host "unpacking '$($stepTemplate)'"
        Export-OctopusStepTemplateScripts -StepTemplate $($stepTemplate.FullName) 
        }
        break
    }
    "pack" {
    function Run-Command ($stepTemplate)
        {
        write-host "packing '$($stepTemplate)'"
        Import-OctopusStepTemplateScripts -StepTemplate $($stepTemplate.FullName)
        }
        break
    }
    default {
        Write-Host "No operation parameter detected, assuming 'unpack'"
        Write-Host "Possible -Op arguments are 'unpack' or 'pack'"
        function Run-Command ($stepTemplate)
        {
            write-host "unpacking '$($stepTemplate)'"
            Export-OctopusStepTemplateScripts -StepTemplate $($stepTemplate.FullName) 
        }
     } 
}

foreach( $stepTemplate in $stepTemplates )
{
    Run-Command $stepTemplate
}