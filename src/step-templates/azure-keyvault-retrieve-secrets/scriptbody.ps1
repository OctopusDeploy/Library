[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

# Variables
$AzVaultModuleName = "Az.KeyVault"
$AzureKeyVaultName = $OctopusParameters["Azure.KeyVault.RetrieveSecrets.VaultName"]
$VaultSecretNames = $OctopusParameters["Azure.KeyVault.RetrieveSecrets.VaultSecrets"]
$AzVaultModuleSpecificVersion = $OctopusParameters["Azure.KeyVault.RetrieveSecrets.AzModule.SpecificVersion"]
$AzVaultModuleCustomInstallLocation = $OctopusParameters["Azure.KeyVault.RetrieveSecrets.AzModule.CustomInstallLocation"]
$PrintVariableNames = $OctopusParameters["Azure.KeyVault.RetrieveSecrets.PrintVariableNames"]

# Validation
if ([string]::IsNullOrWhiteSpace($AzureKeyVaultName)) {
    throw "Required parameter Azure.KeyVault.RetrieveSecrets.VaultName not specified"
}
if ([string]::IsNullOrWhiteSpace($VaultSecretNames)) {
    throw "Required parameter Azure.KeyVault.RetrieveSecrets.VaultSecrets not specified"
}

if ([string]::IsNullOrWhiteSpace($AzVaultModuleSpecificVersion) -eq $False) {
    $requiredVersion = [Version]$AzVaultModuleSpecificVersion
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

$PowerShellModuleName = $AzVaultModuleName

# Check for Custom install location specified for AzVaultModule
if ([string]::IsNullOrWhiteSpace($AzVaultModuleCustomInstallLocation) -eq $false) {
    if ((Test-Path $AzVaultModuleCustomInstallLocation -IsValid) -eq $false) {
        throw "The path $AzVaultModuleCustomInstallLocation is not valid, please use a relative or absolute path."
    }
    
    $AzVaultModulesFolder = [System.IO.Path]::GetFullPath($AzVaultModuleCustomInstallLocation)            
    $LocalModules = (New-Item "$AzVaultModulesFolder" -ItemType Directory -Force).FullName
    $env:PSModulePath = $LocalModules + [System.IO.Path]::PathSeparator + $env:PSModulePath

    # Check to see if there
    if ((Test-Path -Path "$LocalModules/$AzVaultModuleName") -eq $true)
    {
        # Use specific location
        $PowerShellModuleName = "$LocalModules/$PowerShellModuleName"
    }
}

# Import module
if([string]::IsNullOrWhiteSpace($AzVaultModuleSpecificVersion)) {
    Write-Host "Importing module $PowerShellModuleName ..."
    Import-Module -Name $PowerShellModuleName
}
else {
    Write-Host "Importing module $PowerShellModuleName ($AzVaultModuleSpecificVersion)..."
    Import-Module -Name $PowerShellModuleName -RequiredVersion $requiredVersion
}

# Check if Az.Vault Module is installed.
$azVaultModule = Get-Module-CrossPlatform -Name $AzVaultModuleName	
if ($null -eq $azVaultModule) {
    throw "Cannot find the '$AzVaultModuleName' module on the machine. If you think it is installed, try restarting the Tentacle service for it to be detected."	
}

$Secrets = @()
$VariablesCreated = 0
$StepName = $OctopusParameters["Octopus.Step.Name"]

# Extract secret names+versions 
@(($VaultSecretNames -Split "`n").Trim()) | ForEach-Object {
    if (![string]::IsNullOrWhiteSpace($_)) {
        Write-Verbose "Working on: '$_'"
        $secretDefinition = ($_ -Split "\|")
        $secretName = $secretDefinition[0].Trim()
        $secretNameAndVersion = ($secretName -Split " ")
        $secretVersion = $null
        if($secretNameAndVersion.Count -gt 1) {
        	$secretName = $secretNameAndVersion[0].Trim()
            $secretVersion = $secretNameAndVersion[1].Trim()
        }
        if([string]::IsNullOrWhiteSpace($secretName)) {
            throw "Unable to establish secret name from: '$($_)'"
        }
        $secret = [PsCustomObject]@{
            Name         = $secretName
            SecretVersion= $secretVersion
            VariableName = if (![string]::IsNullOrWhiteSpace($secretDefinition[1])) { $secretDefinition[1].Trim() } else { "" }
        }
        $Secrets += $secret
    }
}

Write-Verbose "Vault Name: $AzureKeyVaultName"
Write-Verbose "Print variables: $PrintVariableNames"
Write-Verbose "Secrets to retrieve: $($Secrets.Count)"
Write-Verbose "Az Version specified: $AzVaultModuleSpecificVersion"
Write-Verbose "Az Custom Install Dir: $AzVaultModuleCustomInstallLocation"

# Retrieve Secrets
foreach($secret in $secrets) {
    $name = $secret.Name
    $secretVersion = $secret.SecretVersion
    $variableName = $secret.VariableName
    if ([string]::IsNullOrWhiteSpace($variableName)) {
        $variableName = "$($AzureKeyVaultName.Trim()).$($name.Trim())"
    }
    
    if ([string]::IsNullOrWhiteSpace($secretVersion)) {
    	$azSecretValue = Get-AzKeyVaultSecret -VaultName $AzureKeyVaultName -Name $name -AsPlainText    
    }
    else {
    	$azSecretValue = Get-AzKeyVaultSecret -VaultName $AzureKeyVaultName -Name $name -Version $secretVersion -AsPlainText
    }
    
    Set-OctopusVariable -Name $variableName -Value $azSecretValue -Sensitive

    if($PrintVariableNames -eq $True) {
        Write-Host "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
    }
    $VariablesCreated += 1
}

Write-Host "Created $variablesCreated output variables"