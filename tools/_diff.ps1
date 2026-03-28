param
(
    [Parameter(Mandatory=$true)]
    [string] $SearchPattern,

    [Parameter(Mandatory=$false)]
    [string] $CompareWith = "HEAD~1",

    [Parameter(Mandatory=$false)]
    [string] $OutputFolder = "diff-output"
)

$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

$thisScript  = $MyInvocation.MyCommand.Path;
$thisFolder  = [System.IO.Path]::GetDirectoryName($thisScript);
$repoRoot    = [System.IO.Path]::GetDirectoryName($thisFolder);

$stepTemplateFolder = [System.IO.Path]::Combine($repoRoot, "step-templates");
$stepTemplates = [System.IO.Directory]::GetFiles($stepTemplateFolder, "$SearchPattern.json");

if ($stepTemplates.Length -eq 0)
{
    Write-Error "No step templates found matching '$SearchPattern'";
    return;
}

Import-Module -Name ([System.IO.Path]::Combine($thisFolder, "StepTemplatePacker")) -ErrorAction "Stop";

$outputPath = [System.IO.Path]::Combine($repoRoot, $OutputFolder);
if (-not (Test-Path $outputPath))
{
    New-Item -ItemType Directory -Path $outputPath | Out-Null;
}

$scriptProperties = @(
    @{ Name = "ScriptBody"; Property = "Octopus.Action.Script.ScriptBody" },
    @{ Name = "PreDeploy";  Property = "Octopus.Action.CustomScripts.PreDeploy.ps1" },
    @{ Name = "Deploy";     Property = "Octopus.Action.CustomScripts.Deploy.ps1" },
    @{ Name = "PostDeploy"; Property = "Octopus.Action.CustomScripts.PostDeploy.ps1" }
)

foreach ($stepTemplate in $stepTemplates)
{
    $relativePath = "step-templates/$([System.IO.Path]::GetFileName($stepTemplate))";
    $templateName = [System.IO.Path]::GetFileNameWithoutExtension($stepTemplate);

    $oldJson = $null;
    try
    {
        $oldText = git show "${CompareWith}:${relativePath}" 2>$null;
        if ($LASTEXITCODE -eq 0 -and $oldText)
        {
            $oldJson = ConvertFrom-Json -InputObject ($oldText -join "`n");
        }
    }
    catch
    {
        Write-Host "No previous version found for '$templateName' at $CompareWith" -ForegroundColor Yellow;
        continue;
    }

    $newText = Get-Content -Path $stepTemplate -Raw;
    $newJson = ConvertFrom-Json -InputObject $newText;

    # Get file extension from syntax
    $syntax = Get-OctopusStepTemplateProperty -StepJson $newJson -PropertyName "Octopus.Action.Script.Syntax" -DefaultValue "PowerShell";
    $fileType = Get-OctopusStepTemplateFileType -Syntax $syntax;

    foreach ($prop in $scriptProperties)
    {
        $oldValue = Get-OctopusStepTemplateProperty -StepJson $oldJson -PropertyName $prop.Property;
        $newValue = Get-OctopusStepTemplateProperty -StepJson $newJson -PropertyName $prop.Property;

        if ([string]::IsNullOrEmpty($oldValue) -and [string]::IsNullOrEmpty($newValue)) { continue; }

        $oldFile = [System.IO.Path]::Combine($outputPath, "$templateName.$($prop.Name).old$fileType");
        $newFile = [System.IO.Path]::Combine($outputPath, "$templateName.$($prop.Name).new$fileType");

        Set-Content -Path $oldFile -Value $oldValue -NoNewline;
        Set-Content -Path $newFile -Value $newValue -NoNewline;

        Write-Host "Created: $($prop.Name)" -ForegroundColor Cyan;
        Write-Host "  Old: $oldFile";
        Write-Host "  New: $newFile";
    }
}

Write-Host "";
Write-Host "Files written to: $outputPath" -ForegroundColor Green;
