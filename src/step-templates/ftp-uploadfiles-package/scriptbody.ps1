## --------------------------------------------------------------------------------------
## Input
## --------------------------------------------------------------------------------------
$PathToWinScp = $OctopusParameters['PathToWinScp']
$FtpHost = $OctopusParameters['FtpHost']
$FtpUsername = $OctopusParameters['FtpUsername']
$FtpPassword = $OctopusParameters['FtpPassword']
$FtpHostKeyFingerprint = $OctopusParameters['FtpHostKeyFingerprint']
$FtpPasskey = $OctopusParameters['FtpPasskey']
$FtpPasskeyPhrase = $OctopusParameters['FtpPasskeyPhrase']
$FtpRemoteDirectory = $OctopusParameters['FtpRemoteDirectory']
$FtpDeleteUnrecognizedFiles = $OctopusParameters['FtpDeleteUnrecognizedFiles']
$DeleteDeploymentStep = $OctopusParameters['DeleteDeploymentStep']

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------

function Get-ModuleInstalled
{
    # Define parameters
    param(
        $PowerShellModuleName
    )

    # Check to see if the module is installed
    if ($null -ne (Get-Module -ListAvailable -Name $PowerShellModuleName))
    {
        # It is installed
        return $true
    }
    else
    {
        # Module not installed
        return $false
    }
}

function Install-PowerShellModule
{
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )

	# Check to see if the package provider has been installed
    if ((Get-NugetPackageProviderNotInstalled) -ne $false)
    {
    	# Display that we need the nuget package provider
        Write-Host "Nuget package provider not found, installing ..."
        
        # Install Nuget package provider
        Install-PackageProvider -Name Nuget -Force
    }

	# Save the module in the temporary location
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force
}

function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

# Helper for validating input parameters
function Validate-Parameter([string]$foo, [string[]]$validInput, $parameterName) {
    if (! $parameterName -contains "Password")
    {
        Write-Host "${parameterName}: $foo"
    }
    if (! $foo) {
        throw "No value was set for $parameterName, and it cannot be empty"
    }
}

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

# Session.FileTransferred event handler
function FileTransferred
{
    param($e)

    if ($e.Error -eq $Null)
    {
        Write-Host ("Upload of {0} succeeded" -f $e.FileName)
    }
    else
    {
        Write-Error ("Upload of {0} failed: {1}" -f $e.FileName, $e.Error)
    }

    if ($e.Chmod -ne $Null)
    {
        if ($e.Chmod.Error -eq $Null)
        {
            Write-Host "##octopus[stdout-verbose]"
            Write-Host ("Permisions of {0} set to {1}" -f $e.Chmod.FileName, $e.Chmod.FilePermissions)
            Write-Host "##octopus[stdout-default]"
        }
        else
        {
            Write-Error ("Setting permissions of {0} failed: {1}" -f $e.Chmod.FileName, $e.Chmod.Error)
        }

    }
    else
    {
        Write-Host "##octopus[stdout-verbose]"
        Write-Host ("Permissions of {0} kept with their defaults" -f $e.Destination)
        Write-Host "##octopus[stdout-default]"
    }

    if ($e.Touch -ne $Null)
    {
        if ($e.Touch.Error -eq $Null)
        {
            Write-Host "##octopus[stdout-verbose]"
            Write-Host ("Timestamp of {0} set to {1}" -f $e.Touch.FileName, $e.Touch.LastWriteTime)
            Write-Host "##octopus[stdout-default]"
        }
        else
        {
            Write-Error ("Setting timestamp of {0} failed: {1}" -f $e.Touch.FileName, $e.Touch.Error)
        }

    }
    else
    {
        # This should never happen during "local to remote" synchronization
        Write-Host "##octopus[stdout-verbose]"
        Write-Host ("Timestamp of {0} kept with its default (current time)" -f $e.Destination)
        Write-Host "##octopus[stdout-default]"
    }
}

## --------------------------------------------------------------------------------------
## Configuration
## --------------------------------------------------------------------------------------
# Define PowerShell Modules path
$LocalModules = (New-Item "$PSScriptRoot\Modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules;$env:PSModulePath"
$PowerShellModuleName = "WinSCP"

# Set secure protocols
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

# Check to see if $PathToWinScp is empty
if ([string]::IsNullOrEmpty($PathToWinScp))
{
    # Check to see if WinSCP module is installed
    if ((Get-ModuleInstalled -PowerShellModuleName $PowerShellModuleName) -ne $true)
    {
      # Tell user what we're doing
      Write-Output "PowerShell module $PowerShellModuleName is not installed, downloading temporary copy ..."

      # Install temporary copy
      Install-PowerShellModule -PowerShellModuleName $PowerShellModuleName -LocalModulesPath $LocalModules
      
      # Import module
      Write-Output "Importing $PowerShellModuleName ..."
      Import-Module $PowerShellModuleName
    }
	#Get-ChildItem -Path ([System.IO.Path]::GetDirectoryName((Get-Module $PowerShellModuleName).Path))
	# Get the path to where the dll resides
    #$PathToWinScp = [System.IO.Path]::GetDirectoryName((Get-Module $PowerShellModuleName).Path)
}
else
{
	Validate-Parameter $PathToWinScp -parameterName "Path to WinSCP .NET Assembly"
    # Load WinSCP .NET assembly
    $fullPathToWinScp = "$PathToWinScp\WinSCPnet.dll"
    if(-not (Test-Path $fullPathToWinScp))
    {
        throw "$PathToWinScp does not contain the WinSCP .NET Assembly"
    }
    Add-Type -Path $fullPathToWinScp    
}

#Validate-Parameter $PathToWinScp -parameterName "Path to WinSCP .NET Assembly"
Validate-Parameter $FtpHost -parameterName "Host"
Validate-Parameter $FtpUsername -parameterName "Username"
Validate-Parameter $FtpPassword -parameterName "Password"
Validate-Parameter $FtpRemoteDirectory -parameterName "Remote directory"
Validate-Parameter $FtpDeleteUnrecognizedFiles -parameterName "Delete unrecognized files"

## --------------------------------------------------------------------------------------
## Main script
## --------------------------------------------------------------------------------------

# Load WinSCP .NET assembly
<#
$fullPathToWinScp = "$PathToWinScp\WinSCPnet.dll"
if(-not (Test-Path $fullPathToWinScp))
{
    throw "$PathToWinScp does not contain the WinSCP .NET Assembly"
}
Add-Type -Path $fullPathToWinScp
#>
$stepPath = ""

$stepPath = $OctopusParameters["Octopus.Action.Package[FtpPackage].ExtractedPath"]

Write-Host "Package was installed to: $stepPath"

try
{
    $sessionOptions = New-Object WinSCP.SessionOptions

    # WinSCP defaults to SFTP, but it's good to ensure that's the case
    if (![string]::IsNullOrEmpty($FtpHostKeyFingerprint)) {
      $sessionOptions.Protocol = [WinScp.Protocol]::Sftp
      $sessionOptions.SshHostKeyFingerprint = $FtpHostKeyFingerprint
    }
    else {
      $sessionOptions.Protocol = [WinSCP.Protocol]::Ftp
    }
    $sessionOptions.HostName = $FtpHost
    $sessionOptions.UserName = $FtpUsername

    

    # If there is a path to the private key, use that instead of a password
    if (![string]::IsNullOrEmpty($FtpPasskey)) {
      Write-Host "Attempting to use passkey instead of password"

      # Check key exists
      if (!(Test-Path $FtpPasskey)) {
        throw "Unable to locate passkey at: $FtpPasskey"
      }

      $sessionOptions.SshPrivateKeyPath = $FtpPasskey

      # If the key requires a passphrase to access
      if ($FtpPasskeyPhrase -ne "") {
        $sessionOptions.PrivateKeyPassphrase = $FtpPasskeyPhrase
      }
    }
    else {
      $sessionOptions.Password = $FtpPassword
    }

    $session = New-Object WinSCP.Session
    
    if ([string]::IsNullOrEmpty($PathToWinScp))
    {
    	# Using PowerShell module, need to set the executable location
        $session.ExecutablePath = "$([System.IO.Path]::GetDirectoryName((Get-Module $PowerShellModuleName).Path))\bin\winscp.exe"
    }
    
    try
    {
    
        # Will continuously report progress of synchronization
        $session.add_FileTransferred( { FileTransferred($_) } )

        # Connect
        $session.Open($sessionOptions)

        Write-Host "Beginning synchronization between $stepPath and $FtpRemoteDirectory on $FtpHost"

        if (-not $session.FileExists($FtpRemoteDirectory))
        {
            Write-Host "Remote directory not found, creating $FtpRemoteDirectory"
            $session.CreateDirectory($FtpRemoteDirectory);
        }

        # Synchronize files
        $synchronizationResult = $session.SynchronizeDirectories(
            [WinSCP.SynchronizationMode]::Remote, $stepPath, $FtpRemoteDirectory, $FtpDeleteUnrecognizedFiles)

        # Throw on any error
        $synchronizationResult.Check()
    }
    finally
    {
        # Disconnect, clean up
        $session.Dispose()

        if ($DeleteDeploymentStep) {
          Remove-Item -Path $stepPath -Recurse
        }
    }

    exit 0
}
catch [Exception]
{
    throw $_.Exception.Message
}

