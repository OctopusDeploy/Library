# A collection of functions that can be used by script steps to determine where packages installed
# by previous steps are located on the filesystem.
 
function Find-InstallLocations {
    $result = @()
    $OctopusParameters.Keys | foreach {
        if ($_.EndsWith('].Output.Package.InstallationDirectoryPath')) {
            $result += $OctopusParameters[$_]
        }
    }
    return $result
}
 
function Find-InstallLocation($stepName) {
    $result = $OctopusParameters.Keys | where {
        $_.Equals("Octopus.Action[$stepName].Output.Package.InstallationDirectoryPath",  [System.StringComparison]::OrdinalIgnoreCase)
    } | select -first 1
 
    if ($result) {
        return $OctopusParameters[$result]
    }
 
    throw "No install location found for step: $stepName"
}
 
function Find-SingleInstallLocation {
    $all = @(Find-InstallLocations)
    if ($all.Length -eq 1) {
        return $all[0]
    }
    if ($all.Length -eq 0) {
        throw "No package steps found"
    }
    throw "Multiple package steps have run; please specify a single step"
}

function Test-LastExit($cmd) {
    if ($LastExitCode -ne 0) {
        Write-Host "##octopus[stderr-error]"
        write-error "$cmd failed with exit code: $LastExitCode"
    }
}




$stepName = $OctopusParameters['NugetPackageStepName']

$stepPath = ""
if (-not [string]::IsNullOrEmpty($stepName)) {
    Write-Host "Finding path to package step: $stepName"
    $stepPath = Find-InstallLocation $stepName
} else {
    $stepPath = Find-SingleInstallLocation
}
Write-Host "Package was installed to: $stepPath"

$baseDirectory = $OctopusParameters['BaseDirectory']

$binPath = Join-Path $stepPath $baseDirectory

#Locate Migrate.exe
$efToolsFolder = $OctopusParameters['EfToolsFolder']
$originalMigrateExe = Join-Path $efToolsFolder "migrate.exe"

if (-Not(Test-Path $originalMigrateExe)){
    throw ("Unable to locate migrate.exe file. Specifed path $originalMigrateExe does not exist.")
}
Write-Host("Found Migrate.Exe from $originalMigrateExe")

$migrateExe = Join-Path $binPath "migrate.exe"
if (-Not(Test-Path $migrateExe)) {
    # Move migrate.exe to ASP.NET Project's bin folder as per https://msdn.microsoft.com/de-de/data/jj618307.aspx?f=255&MSPPError=-2147217396
    Copy-Item $originalMigrateExe -Destination $binPath
    Write-Host("Copied $originalMigrateExe into $binPath")
}

#Locate Assembly with DbContext class
$contextDllName = $OctopusParameters['AssemblyDllName']
$contextDllPath = Join-Path $binPath $contextDllName
if (-Not(Test-Path $contextDllPath)){
    throw ("Unable to locate assembly file with DbContext class. Specifed path $contextDllPath does not exist.")
}
Write-Host("Using $contextDllName from $contextDllPath")

#Locate web.config. Migrate.exe needs it for some reason, even if connection string is provided
$configFile = $OctopusParameters['ConfigFileName']
$configPath = Join-Path $stepPath $configFile
if (-Not(Test-Path $configPath)){
    throw ("Unable to locate config file. Specifed path $webConfigPath does not exist.")
}

$connectionStringName = $OctopusParameters['ConnectionStringName']

$migrateCommand = "& ""$migrateExe"" ""$contextDllName"" /connectionStringName=""$connectionStringName"" /startupConfigurationFile=""$configPath"" /startUpDirectory=""$binPath"" /Verbose"

Write-Host "##octopus[stderr-error]"        # Stderr is an error
Write-Host "Executing: " $migrateCommand
Write-Host 

Invoke-Expression $migrateCommand | Write-Host

# Remove migrate.exe from the bin folder as it is not part of the application
If (Test-Path $migrateExe)
{
  Write-Host "Deleting " $migrateExe
  Remove-Item $migrateExe
}
