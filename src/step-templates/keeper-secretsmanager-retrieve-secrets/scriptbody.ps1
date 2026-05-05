$ErrorActionPreference = 'Stop'

# Variables
$KsmModuleName = "SecretManagement.Keeper.Extension"
$KsmParentModuleName = "SecretManagement.Keeper"
$KsmConfig = $OctopusParameters["Keeper.SecretsManager.RetrieveSecrets.Config"]
$VaultSecrets = $OctopusParameters["Keeper.SecretsManager.RetrieveSecrets.VaultSecrets"]
$KsmModuleSpecificVersion = $OctopusParameters["Keeper.SecretsManager.RetrieveSecrets.KsmModule.SpecificVersion"]
$KsmModuleCustomInstallLocation = $OctopusParameters["Keeper.SecretsManager.RetrieveSecrets.KsmModule.CustomInstallLocation"]
$PrintVariableNames = $OctopusParameters["Keeper.SecretsManager.RetrieveSecrets.PrintVariableNames"]

# Validation
if ([string]::IsNullOrWhiteSpace($VaultSecrets)) {
    throw "Required parameter Keeper.SecretsManager.RetrieveSecrets.VaultSecrets not specified"
}

if ([string]::IsNullOrWhiteSpace($KsmModuleSpecificVersion) -eq $False) {
    $requiredVersion = [Version]$KdmModuleSpecificVersion
}

# Cross-platform bits
$WindowsPowerShell = $True
if ($PSEdition -eq "Core") {
    $WindowsPowerShell = $False
}

### Helper functions
function Get-Module-CrossPlatform {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name
    )

    $module = Get-Module -Name $Name -ListAvailable
    if($WindowsPowerShell -eq $True -and $null -eq $module) {
        $module = Get-InstalledModule -Name $Name
    }

    return $module
}

function Load-Module {
    Param(
        [Parameter(Mandatory = $true)][string] $name
    )

    $retVal = $true
    if (!(Get-Module -Name $name)) {
        $isAvailable = Get-Module -ListAvailable | where { $_.Name -eq $name }
        if ($isAvailable) {
            try {
                Import-Module $name -ErrorAction SilentlyContinue
            } catch {
                $retVal = $false
            }
        } else {
            $retVal = $false
        }
    }
    return $retVal
}

$PowerShellModuleName = $KsmModuleName

# Check for Custom install location specified for KsmModule
if ([string]::IsNullOrWhiteSpace($KsmModuleCustomInstallLocation) -eq $false) {
    if ((Test-Path $KsmModuleCustomInstallLocation -IsValid) -eq $false) {
        throw "The path $KsmModuleCustomInstallLocation is not valid, please use a relative or absolute path."
    }
    
    $KsmModulesFolder = [System.IO.Path]::GetFullPath($KsmModuleCustomInstallLocation)
    $LocalModules = (New-Item "$KsmModulesFolder" -ItemType Directory -Force).FullName
    $env:PSModulePath = $LocalModules + [System.IO.Path]::PathSeparator + $env:PSModulePath

    # Check to see if there
    if ((Test-Path -Path "$LocalModules/$KsmModuleName") -eq $true)
    {
        # Use specific location
        $PowerShellModuleName = "$LocalModules/$PowerShellModuleName"
    }
}

# Import module
if([string]::IsNullOrWhiteSpace($KsmModuleSpecificVersion)) {
    Write-Host "Importing module $PowerShellModuleName ..."
    if ((Load-Module -Name $PowerShellModuleName) -eq $false) {
        Write-Host "Extension module not found $PowerShellModuleName - trying to find sub-module in parent $KsmParentModuleName"
        if (Get-Module -ListAvailable -Name $KsmParentModuleName) {
            $KsmParentModuleDir = Split-Path -Path (Get-Module -ListAvailable -Name $KsmParentModuleName).Path
            $KsmModuleFolder = [System.IO.Path]::GetFullPath($KsmParentModuleDir)
            $LocalModules = (New-Item "$KsmModuleFolder" -ItemType Directory -Force).FullName
            $env:PSModulePath = $LocalModules + [System.IO.Path]::PathSeparator + $env:PSModulePath

            if ((Test-Path -Path "$LocalModules/$KsmModuleName") -eq $true)
            {
                $PowerShellModuleName = "$LocalModules/$PowerShellModuleName"
                try {
                    Import-Module -Name $PowerShellModuleName -ErrorAction SilentlyContinue
                    Write-Host "Imported sub-module $PowerShellModuleName ..."
                } catch {
                    Write-Host "Failed to import sub-module $PowerShellModuleName ..."
                }
            }
        } else {
            Write-Host "Module does not exist"
        }
    }
}
else {
    Write-Host "Importing module $PowerShellModuleName ($KsmModuleSpecificVersion)..."
    Import-Module -Name $PowerShellModuleName -RequiredVersion $requiredVersion
}

# Check if SecretManagement.Keeper.Extension Module is installed.
$ksmVaultModule = Get-Module-CrossPlatform -Name $KsmModuleName
if ($null -eq $ksmVaultModule) {
    throw "Cannot find the '$KsmModuleName' module on the machine. If you think it is installed, try restarting the Tentacle service for it to be detected."
}

$Secrets = @()
$VariablesCreated = 0
$StepName = $OctopusParameters["Octopus.Step.Name"]

# Extract lines and split into notations and variables
$index = 0
$usedNames = @()
@(($VaultSecrets -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"

        # Split 'Notation | VariableName' and generate new var name if needed
        $notation = $_
        $variableName = ""
        $n = $_.LastIndexOf("|")
        if ($n -ge 0) {
            if ($n -lt $notation.Length-1) {
                $variableName = $notation.SubString($n+1).Trim()
            }
            $notation = $notation.SubString(0, $n).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($variableName)) {
            do {
                $index++
                $variableName = "KsmSecret" + $index
            } while ($usedNames.Contains($variableName))
        }
        # Duplicate var - either overlapping KsmSecretN or another user variable
        if($usedNames.Contains($variableName)) {
            throw "Duplicate variable name: '$variableName'"
        }
        $usedNames += $variableName

        if([string]::IsNullOrWhiteSpace($notation)) {
            throw "Unable to establish notation URI from: '$($_)'"
        }
        $secret = [PsCustomObject]@{
            Notation         = $notation
            VariableName = $variableName
        }
        $Secrets += $secret
    }
}

Write-Verbose "Print variables: $PrintVariableNames"
Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "KSM Version specified: $KsmModuleSpecificVersion"
Write-Verbose "KSM Custom Install Dir: $KsmModuleCustomInstallLocation"

# Retrieve Secrets
foreach($secret in $secrets) {
    $notation = $secret.Notation
    $variableName = $secret.VariableName

    $ksmSecretValue = Get-Notation -Notation $notation -Config $KsmConfig

    Set-OctopusVariable -Name $variableName -Value $ksmSecretValue -Sensitive

    if($PrintVariableNames -eq $True) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
    }
    $VariablesCreated += 1
}

Write-Host "Created $variablesCreated output variables"
