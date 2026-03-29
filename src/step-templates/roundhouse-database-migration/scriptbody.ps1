# Configure template

# Check to see if $IsWindows is available
if ($null -eq $IsWindows)
{
	Write-Host "Determining Operating System..."
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

# Define parameters
$roundhouseExecutable = ""
$roundhouseOutputPath = [System.IO.Path]::Combine($OctopusParameters["Octopus.Action.Package[RoundhousEPackage].ExtractedPath"], "output")
$roundhouseSsl = [System.Convert]::ToBoolean($roundhouseSsl)

# Determines latest version of github repo
Function Get-LatestVersionNumber
{
    # Define parameters
    param ($GitHubRepository)
        
    # Define local variables
    $releases = "https://api.github.com/repos/$GitHubRepository/releases"
    
    # Get latest version
    Write-Host "Determining latest release ($releases) ..."
    
    $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)
    
    # Find the latest version with a downloadable asset
    foreach ($tag in $tags)
    {
        if ($tag.assets.Count -gt 0)
        {
            #return $tag.assets.browser_download_url
            return $tag.tag_name
        }
    }

    # Return the version
    return $null    
}

# Change the location to the extract path
Set-Location -Path $OctopusParameters["Octopus.Action.Package[RoundhousEPackage].ExtractedPath"]

# Check to see if download is specified
if ([System.Boolean]::Parse($roundhouseDownloadNuget))
{
    # Set secure protocols
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

	# Check to see if version number specified
    if ([string]::IsNullOrEmpty($roundhouseNugetVersion))
    {
    	# Get the latest version number
        $roundhouseNugetVersion = Get-LatestVersionNumber -GitHubRepository "chucknorris/roundhouse"
    }

    # Check for download folder
    if ((Test-Path -Path "$PSSCriptRoot\roundhouse") -eq $false)
    {
        # Create the folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot\roundhouse"
    }
    
    # Download nuget package
    Write-Output "Downloading https://github.com/chucknorris/roundhouse/releases/download/$roundhouseNugetVersion/dotnet-roundhouse.$roundhouseNugetVersion.nupkg ..."
    Invoke-WebRequest -Uri "https://github.com/chucknorris/roundhouse/releases/download/$roundhouseNugetVersion/dotnet-roundhouse.$roundhouseNugetVersion.nupkg" -OutFile "$PSSCriptRoot\roundhouse\dotnet-roundhouse.$roundhouseNugetVersion.nupkg"

    # Change file extension
    $nugetPackage = Get-ChildItem -Path "$PSSCriptRoot\roundhouse\dotnet-roundhouse.$roundhouseNugetVersion.nupkg"
    $nugetPackage | Rename-Item -NewName $nugetPackage.Name.Replace(".nupkg", ".zip")
    
    # Extract the package
    Write-Output "Extracting dotnet-roundhouse.$roundhouseNugetVersion.nupkg ..."
    Expand-Archive -Path "$PSSCriptRoot\roundhouse\dotnet-roundhouse.$roundhouseNugetVersion.zip" -DestinationPath "$PSSCriptRoot\roundhouse"
}

# Set Executable depending on OS
if ($IsWindows)
{
  # Look for older .exe
  $roundhouseExecutable = Get-ChildItem -Path $PSSCriptRoot -Recurse | Where-Object {$_.Name -eq "rh.exe"}
}

if ([string]::IsNullOrWhitespace($roundhouseExecutable))
{
	# Look for just rh.dll
    $roundhouseExecutable = Get-ChildItem -Path $PSSCriptRoot -Recurse | Where-Object {$_.Name -eq "rh.dll"}
}

if ([string]::IsNullOrWhitespace($roundhouseExecutable))
{
    # Couldn't find RoundhousE
    Write-Error "Couldn't find the RoundhousE executable!"
}

# Build the arguments
$roundhouseSwitches = @()

# Update the connection string based on authentication method
switch ($roundhouseAuthenticationMethod)
{
    "awsiam"
    {
        # Region is part of the RDS endpoint, extract
        $region = ($roundhouseServerName.Split("."))[2]

        Write-Host "Generating AWS IAM token ..."
        $roundhouseUserPassword = (aws rds generate-db-auth-token --hostname $roundhouseServerName --region $region --port $roundhouseServerPort --username $roundhouseUserName)       
        $roundhouseUserInfo = "Uid=$roundhouseUserName;Pwd=$roundhouseUserPassword;"

        break
    }

    "usernamepassword"
    {
    	# Append remaining portion of connection string
        $roundhouseUserInfo = "Uid=$roundhouseUserName;Pwd=$roundhouseUserPassword;"

		break    
	}

    "windowsauthentication"
    {
      # Append remaining portion of connection string
	  $roundhouseUserInfo = "integrated security=true;"
      
      # Append username (required for non
      $roundhouseUserInfo += "Uid=$roundhouseUserName;"
    }
}


# Configure connnection string based on technology
switch ($roundhouseDatabaseServerType)
{
    "sqlserver"
    {
        # Check to see if port has been defined
        if (![string]::IsNullOrEmpty($roundhouseServerPort))
        {
            # Append to servername
            $roundhouseServerName += ",$roundhouseServerPort"

            # Empty the port
            $roundhouseServerPort = [string]::Empty
        }
    }
    "mariadb"
    {
    	# Use the MySQL client
        $roundhouseDatabaseServerType = "mysql"
        $roundhouseServerPort = "Port=$roundhouseServerPort;"
    }
    default
    {
        $roundhouseServerPort = "Port=$roundhouseServerPort;"
    }
}

# Build base connection string
$roundhouseServerConnectionString = "--connectionstring=Server=$roundhouseServerName;$roundhouseServerPort $roundhouseUserInfo Database=$roundhouseDatabaseName;"

if ($roundhouseSsl -eq $true)
{
	if (($roundhouseDatabaseServerType -eq "mariadb") -or ($roundhouseDatabaseServerType -eq "mysql") -or ($roundhouseDatabaseServerType -eq "postgres"))
    {
    	# Add sslmode
        $roundhouseServerConnectionString += "SslMode=Require;Trust Server Certificate=true;"
    }
    else
    {
    	Write-Warning "Invalid Database Server Type selection for SSL, ignoring setting."
    }
}

$roundhouseSwitches += $roundhouseServerConnectionString

$roundhouseSwitches += "--databasetype=$roundhouseDatabaseServerType"
$roundhouseSwitches += "--silent"


# Check for folder definitions
if (![string]::IsNullOrEmpty($roundhouseUpFolder))
{
    # Add up folder
    $roundhouseSwitches += "--up=$roundhouseUpFolder"
}

if (![string]::IsNullOrEmpty($roundhouseAlterDatabaseFolder))
{
    $roundhouseSwitches += "--alterdatabasefolder=$roundhouseAlterDatabaseFolder"
}

if (![string]::IsNullOrEmpty($roundhouseRunBeforeUpFolder))
{
    $roundhouseSwitches += "--runbeforeupfolder=$roundhouseRunBeforeUpFolder"
}

if (![string]::IsNullOrEmpty($roundhouseFunctionsFolder))
{
    $roundhouseSwitches += "--functionsfolder=$roundhouseFunctionsFolder"
}

if (![string]::IsNullOrEmpty($roundhouseViewsFolder))
{
    $roundhouseSwitches += "--viewsfolder=$roundhouseViewsFolder"
}

if (![string]::IsNullOrEmpty($roundhouseSprocsFolder))
{
    $roundhouseSwitches += "--sprocsfolder=$roundhouseSprocsFolder"
}

if (![string]::IsNullOrEmpty($roundhouseIndexFolder))
{
    $roundhouseSwitches += "--indexesfolder=$roundhouseIndexFolder"
}

if (![string]::IsNullOrEmpty($roundhouseRunAfterAnyTimeFolder))
{
    $roundhouseSwitches += "--runAfterOtherAnyTimeScriptsFolder=$roundhouseRunAfterAnyTimeFolder"
}

if (![string]::IsNullOrEmpty($roundhousePermissionsFolder))
{
    $roundhouseSwitches += "--permissionsfolder=$roundhousePermissionsFolder"
}

if (![string]::IsNullOrEmpty($roundhouseTriggerFolder))
{
    $roundhouseSwitches += "--triggersfolder=$roundhouseTriggerFolder"
}

if ([System.Boolean]::Parse($roundhouseDryRun))
{
    $roundhouseSwitches += "--dryrun"
}

if ([System.Boolean]::Parse($roundhouseRecordOutput))
{
    $roundhouseSwitches += "--outputpath=$roundhouseOutputPath"
}

# Add transaction switch
$roundhouseSwitches += "--withtransaction=$($roundhouseWithTransaction.ToLower())"

# Check for version
if (![string]::IsNullOrEmpty($roundhouseVersion))
{
    # Add version
    $roundhouseSwitches += "--version=$roundhouseVersion"
}

# Display what's going to be run
if (![string]::IsNullOrWhitespace($roundhouseUserPassword))
{
	Write-Host "Executing $($roundhouseExecutable.FullName) with $($roundhouseSwitches.Replace($roundhouseUserPassword, "****"))"
}
else
{
	Write-Host "Executing $($roundhouseExecutable.FullName) with $($roundhouseSwitches)"
}

# Execute RoundhousE
if ($roundhouseExecutable.FullName.EndsWith(".dll"))
{
	& dotnet $roundhouseExecutable.FullName $roundhouseSwitches
}
else
{
	& $roundhouseExecutable.FullName $roundhouseSwitches
}

# If the output path was specified, attach artifacts
if ([System.Boolean]::Parse($roundhouseRecordOutput))
{    
    # Zip up output folder content
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    
    $zipFile = "$($OctopusParameters["Octopus.Action.Package[RoundhousEPackage].ExtractedPath"])/output.zip"
    
	[System.IO.Compression.ZipFile]::CreateFromDirectory($roundhouseOutputPath, $zipFile)
    New-OctopusArtifact -Path "$zipFile" -Name "output.zip"
}
