Write-Host "Determining Operating System..."
# Check to see if $IsWindows is available
if ($null -eq $IsWindows)
{
    switch ([System.Environment]::OSVersion.Platform)
    {
    	"Win32NT"
        {
        	# Set variable
            $IsWindows = $true
            $IsLinux = $false
        }
        "Unix"
        {
        	$IsWindows = $false
            $IsLinux = $true
        }
    }
}

if ($IsWindows)
{
	Write-Host "Detected OS is Windows"
    $ProgressPreference = 'SilentlyContinue'
}
else
{
	Write-Host "Detected OS is Linux"
}

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Get working variables
$packageExtractedPath = $OctopusParameters['Octopus.Action.Package[Template.Package].ExtractedPath']
$originalPath = $OctopusParameters['Octopus.Action.Package[Template.Package].OriginalPath']
$packageId = $OctopusParameters['Octopus.Action.Package[Template.Package].PackageId']
$packageVersion = $OctopusParameters['Octopus.Action.Package[Template.Package].PackageVersion']
$azureResourceGroupName = $OctopusParameters['Template.Azure.ResourceGroup.Name']
$azureServiceName = $OctopusParameters['Template.Azure.Service.Name']
$azureServiceType = $OctopusParameters['Template.Azure.Service.Type']
$slotName = $OctopusParameters['Template.Slot.Name']

# Check for Windows
if ($isWindows)
{
  ###########
  # Okay, I know this looks really weird, but during development and testing, I found that the method used in the else statement did something weird to the archive where
  # the deployment would fail, claiming the .azurfunctions folder is missing when it is clearly there only on Windows.  Grabbing the original file and only updating the changed files
  # from the variable replacement operations and uploading the updated file seems to work
  ###########
  # Grab the original archive file
  Copy-Item -Path $originalPath -Destination "$PWD/$($packageId).$($packageVersion).zip"

  # Update the original archive with the items from the repackaged one so it includes any replacement
  Compress-Archive -Path "$packageExtractedPath/*" -DestinationPath "$PWD/$($packageId).$($packageVersion).zip"  -Update
}
else
{
  # Repackage the files
  Get-ChildItem -Path $packageExtractedPath -Force | Compress-Archive -DestinationPath "$PWD/$($packageId).$($packageVersion).zip"
}

$archiveFile = Get-ChildItem -Path "$PWD/$($packageId).$($packageVersion).zip"

# Create argument array
$commandArguments = @()

# Deploy the service
switch ($azureServiceType)
{
  "functionapp"
  {
    # Append functionapp specific arguments
    $commandArguments += @("functionapp")
    break
  }
  "webapp"
  {
    $commandArguments += @("webapp")
    break
  }
}

# Add additional arguments
$commandArguments += @("deployment", "source", "config-zip", "--src", "$($archiveFile.FullName)", "--resource-group", "$azureResourceGroupName", "--name", "$azureServiceName")

# Check to see if they're using slots
if (![string]::IsNullOrWhitespace($slotName))
{
  $commandArguments += @("--slot", "$slotName")
}

# Execute command
Write-Host "Executing: az $commandArguments"



# Redirection of stderr to stdout is done different on Windows versus Linux
if ($IsWindows) {
    $commandArguments += @("2>&1")
    # Execute Liquibase
    az $commandArguments
}

if ($IsLinux) {
    # Execute Liquibase
    az $commandArguments 2>&1
}

# Check exit code
if ($lastExitCode -ne 0) {
    # Fail the step
    Write-Error "Deployment failed!"
}


#az $commandArguments