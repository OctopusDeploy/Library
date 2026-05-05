$ErrorActionPreference = 'Stop'

function Confirm-Argument($name, $value) {
    if (!$value) {
        throw ('Missing required value for parameter ''{0}''.' -f $name)
    }
    return $value
}

# Returns the Microsoft.AnalysisServices.Deployment.exe path
function Get-SSASexe
{
	# Search for file
    $ssasExe = Get-ChildItem -Path "C:\Program Files (x86)" -Recurse | Where-Object {$_.Name -eq "Microsoft.AnalysisServices.Deployment.exe"}
    
    # Check for null
    if ($null -eq $ssasExe)
    {
    	# Display error
        Write-Error "Unable to find Microsoft.AnalysisServices.Deployment.exe!"
    }

    # Check for mulitple results
    if ($ssasExe.GetType().IsArray)
    {
        # Declare local variables
        $highestVersion = $null
        
        # Display multiple returned
        Write-Host "Multiple files returned, finding highest version ..."

        # Loop through results
        foreach ($file in $ssasExe)
        {
            # Check version 
            if (($null -eq $highestVersion) -or ([version]$file.VersionInfo.ProductVersion) -gt [version]$highestVersion.VersionInfo.ProductVersion)
            {
                # Assign it
                $highestVersion = $file
            }
        }

        # Overwrite original
        $ssasExe = $highestVersion
    }
    
    # Return the path
    return $ssasExe.FullName
}

# Update Deploy xml (.deploymenttargets)
function Update-Deploy {
	[xml]$deployContent = Get-Content $file
	$deployContent.DeploymentTarget.Database = $ssasDatabase 
	$deployContent.DeploymentTarget.Server = $ssasServer
	$deployContent.DeploymentTarget.ConnectionString = 'DataSource=' + $ssasServer + ';Timeout=0'
	$deployContent.Save($file)
}
# Update Config xml (.configsettings)
function Update-Config {
	[xml]$configContent = Get-Content $file
    $configContent.ConfigurationSettings.Database.DataSources.DataSource.ConnectionString = 'Provider=SQLNCLI11.1;Data Source=' + $dbServer + ';Integrated Security=SSPI;Initial Catalog=' + $dbDatabase
	$configContent.Save($file)
}
# Update Config xml (.deploymentoptions)
function Update-Option {
	[xml]$optionContent = Get-Content $file
    $optionContent.DeploymentOptions.ProcessingOption = 'DoNotProcess'
	$optionContent.Save($file)
}

# Get arguments
$ssasPackageStepName = Confirm-Argument 'SSAS Package Step Name' $OctopusParameters['SsasPackageStepName']
$ssasServer = Confirm-Argument 'SSAS server name' $OctopusParameters['SsasServer']
$ssasDatabase = Confirm-Argument 'SSAS database name' $OctopusParameters['SsasDatabase']
$dbServer = Confirm-Argument 'SSAS source server' $OctopusParameters['SrcServer']
$dbDatabase = Confirm-Argument 'SSAS source database' $OctopusParameters['SrcDatabase']

# Set .NET CurrentDirectory to package installation path
$installDirPathFormat = 'Octopus.Action[{0}].Output.Package.InstallationDirectoryPath' -f $ssasPackageStepName
$installDirPath = $OctopusParameters[$installDirPathFormat]

Write-Verbose ('Setting CurrentDirectory to ''{0}''' -f $installDirPath)
[System.Environment]::CurrentDirectory = $installDirPath

# Get SSAS exe location
$exe = Get-SSASexe

$files = Get-ChildItem –Path $installDirPath\* -Include *.deploymenttargets
foreach ($file in $files) {
  $name = [IO.Path]::GetFileNameWithoutExtension($file)

  Write-Host 'Updating' $file
  Update-Deploy
  $file = $installDirPath + '\' + $name + '.configsettings'
  if(Test-Path $file) {
      Write-Host 'Updating' $file
      Update-Config
  } else {
    Write-Host "Config settings doesn't exist. Skipping."
  }
  $file = $installDirPath + '\' + $name + '.deploymentoptions'
  Write-Host 'Updating' $file
  Update-Option

  $ssasArguments = @()
  $ssasArguments += ('"' + $installDirPath + '\' + $name + '.asdatabase"')
  $ssasArguments += '/s:"' + $installDirPath + '\Log.txt"'
  
  Write-Host $exe $ssasArguments
  & $exe $ssasArguments
  
  # Get last exit code
  $ssasExitCode = $LastExitcode
  
  # Check to make sure log file exists
  if ((Test-Path -Path "$installDirPath\Log.txt") -eq $true)
  {
    # Upload log as artifact
    New-OctopusArtifact -Path "$installDirPath\Log.txt" -Name "Log.txt"
  }
  else
  {
    # Write error
    Write-Error "Error: $installDirPath\Log.txt not found!"
  }
  
  # Check the code
  if ($ssasExitCode -ne 0)
  {
  	Write-Error "Operation failed, see log for details."
  }
}
