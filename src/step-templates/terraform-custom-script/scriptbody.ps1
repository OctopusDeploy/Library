$DynamicPackageName = "InfrastructurePackage" 
$AccountVariableName = "TerraformScript.AzureAccount"
# Version of the terrform package - used to substitute Octopus.Release.Number in tfvars file
$packageVersion = $OctopusParameters["Octopus.Action.Package[$DynamicPackageName].PackageVersion"]
# Override the package version with a custom version string - used to substitute Octopus.Release.Number in tfvars file
$userOverridenVersionNumber = $OctopusParameters["TerraformScript.Octopus.Release.Number"]
# Should we call terraform init before the script?
$runInit = [System.Convert]::ToBoolean($OctopusParameters["TerraformScript.RunInitBeforeScript"]) 

$versionNumberToSubstitute = If ($userOverridenVersionNumber) { $userOverridenVersionNumber } else { $packageVersion }
$versionNumberSubstitutionFilesPattern = if ( $OctopusParameters["TerraformScript.versionNumberSubstitutionFilesPattern"]) {
    $OctopusParameters["TerraformScript.VersionNumberSubstitutionFilesPattern"]
}
else {
    "*.tf*"
}

# Should Octopus collect all terraform files from the package after execution as artefacts?
$collectArtefacts = if ($OctopusParameters["TerraformScript.CollectArtefacts"]) { 
    [System.Convert]::ToBoolean($OctopusParameters["TerraformScript.CollectArtefacts"]) 
} 
else { $false }
# override pattern to match (terraform) files like *.t* when collecting artefacts
$artefactNameLikePattern = if ($OctopusParameters["TerraformScript.ArtefactNameLikePattern"]) { 
    $OctopusParameters["TerraformScript.ArtefactNameLikePattern"] 
}
else { 
    "*.tf*"
}
# Detect if we have Azure Account credentials from a variable and log in to azure
$HasAzureAccount = if ($OctopusParameters["$AccountVariableName.Client"]) { $true } else { $false }
# The path where the package containing terraform files is extracted to disk - usually just ./InfrastructurePackage
$terraformPackageFolder = $OctopusParameters["Octopus.Action.Package[$DynamicPackageName].ExtractedPath"];
# Override the location of the terraform exe - otherwise assume terraform is available on PATH
$CustomTerraformExe = $OctopusParameters["Octopus.Action.Terraform.CustomTerraformExecutable"]
# The terraform script to be executed
$terraformCliScriptToExecute = [Scriptblock]::Create($OctopusParameters["TerraformScript.CliScript"])

# If we have service principal creds to Azure then set ENV variables so that azurerm can authenticate
if ($HasAzureAccount) {
    Write-host "Selecting azure subscription $($OctopusParameters["$AccountVariableName.SubscriptionNumber"]) using $AccountVariableName variable"
  
    $ENV:ARM_CLIENT_ID = $OctopusParameters["$AccountVariableName.Client"]
    $ENV:ARM_CLIENT_SECRET = $OctopusParameters["$AccountVariableName.Password"]
    $ENV:ARM_SUBSCRIPTION_ID = $OctopusParameters["$AccountVariableName.SubscriptionNumber"]
    $ENV:ARM_TENANT_ID = $OctopusParameters["$AccountVariableName.TenantId"]
}

Function Invoke-Exec {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = 1)][scriptblock]$cmd
    )
    $scriptExpanded = $ExecutionContext.InvokeCommand.ExpandString($cmd).Trim().Trim("&")
    Write-Verbose "Executing command: $scriptExpanded"

    & $cmd | Out-Default

    if ($lastexitcode -ne 0) {
        throw ("Non-zero exit code '$lastexitcode' detected from command: '$scriptExpanded'")
    }
}

#================= Prep to run terraform ========================

# List the contents of the package - useful debugging
Write-Verbose "Using package contents:"
Get-ChildItem $terraformPackageFolder -Verbose

# Use a custom version of terraform? If so add it to the path for this sesssion. Otherwise assume terraform already on PATH
if ($CustomTerraformExe) {
    $terraformfolder = Split-Path $CustomTerraformExe;
    # add custom terraform to path if required
    if ($ENV:PATH -notcontains $terraformfolder) { 
        $ENV:PATH += ";$terraformfolder"; 
    }
    Write-Verbose "PATH: $ENV:PATH"
    Write-Host "`nUsing terraform.exe from $terraformExePath"
}

Write-Host "Running in $terraformPackageFolder"
Set-Location $terraformPackageFolder

# Substitute #{Octopus.Release.Number} in *.tf files because that variable is not availe during runbook execution
Get-ChildItem . -file | Where-Object { $_.Name -like $versionNumberSubstitutionFilesPattern } | ForEach-Object {
    Write-Host "Replacing #{Octopus.Release.Number} in $($_.FullName) with $versionNumberToSubstitute"
    (Get-Content $_.FullName) -replace "#{Octopus.Release.Number}", $versionNumberToSubstitute | Set-Content $_.FullName
}   

#================= terraform init ========================

# optionally initialise terraform
if($runInit) {
  Write-Host "`n terraform init`n"
  terraform init -no-color
}
#================= Run terraform script ========================

try {
    # Execute the provided script
    Invoke-Exec $terraformCliScriptToExecute
}
finally {
    # optionally collect all terraform files as artefacts
    if ($collectArtefacts) {
        Get-ChildItem . -File | Where-Object { $_.name -like $artefactNameLikePattern } | New-OctopusArtifact
    }
}
