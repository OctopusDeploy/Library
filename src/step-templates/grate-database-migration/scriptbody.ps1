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

if ($IsWindows)
{
	$ProgressPreference = 'SilentlyContinue'
}

# Define parameters
$grateExecutable = ""
$grateOutputPath = [System.IO.Path]::Combine($OctopusParameters["Octopus.Action.Package[gratePackage].ExtractedPath"], "output")
$grateSsl = [System.Convert]::ToBoolean($grateSsl)

Function Get-LatestVersionDownloadUrl {
    # Define parameters
    param(
        $Repository,
        $Version
    )
    
    # Define local variables
    $releases = "https://api.github.com/repos/$Repository/releases"
    
    # Get latest version
    Write-Host "Determining latest release of $Repository ..."
    
    $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)
    
    if ($null -ne $Version) {
        # Get specific version
        $tags = ($tags | Where-Object { $_.tag_name.EndsWith($Version) })

        # Check to see if nothing was returned
        if ($null -eq $tags) {
            # Not found
            Write-Host "No release found matching version $Version, getting highest version using Major.Minor syntax..."

            # Get the tags
            $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)

            # Parse the version number into a version object
            $parsedVersion = [System.Version]::Parse($Version)
            $partialVersion = "$($parsedVersion.Major).$($parsedVersion.Minor)"

            # Filter tags to ones matching only Major.Minor of version specified
            $tags = ($tags | Where-Object { $_.tag_name.Contains("$partialVersion.") -and $_.draft -eq $false })
            
            # Grab the latest
            if ($null -eq $tags)
            {
            	# decrement minor version
                $minorVersion = [int]$parsedVersion.Minor
                $minorVersion --
                
                # Check to make sure that minor version isn't negative
                if ($minorVersion -ge 0)
                {
                	# return the urls
                	return (Get-LatestVersionDownloadUrl -Repository $Repository -Version "$($parsedVersion.Major).$($minorVersion)")
                }
                else
                {
                	# Display error
                    Write-Error "Unable to find a version within the major version of $($parsedVersion.Major)!"
                }
            }
        }
    }

    # Find the latest version with a downloadable asset
    foreach ($tag in $tags) {
        if ($tag.assets.Count -gt 0) {
            return $tag.assets.browser_download_url
        }
    }

    # Return the version
    return $null
}

# Change the location to the extract path
Set-Location -Path $OctopusParameters["Octopus.Action.Package[gratePackage].ExtractedPath"]

$grateVersionNumber = $null

# Check to see if download is specified
if ([System.Boolean]::Parse($grateDownloadNuget))
{
    # Set secure protocols
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
    $downloadUrls = @()

	# Check to see if version number specified
    if ([string]::IsNullOrWhitespace($grateNugetVersion))
    {
    	# Get the latest version number
        $downloadUrls = Get-LatestVersionDownloadUrl -Repository "grate-devs/grate"
    }
    else
    {
    	# Get specific version
        $downloadUrls = Get-LatestVersionDownloadUrl -Repository "grate-devs/grate" -Version $grateNugetVersion
    }

	# Check to make sure something was returned
    if ($null -ne $downloadUrls -and $downloadUrls.Length -gt 0)
	{
    
      # Check for download folder
      if ((Test-Path -Path "$PSSCriptRoot/grate") -eq $false)
      {
          # Create the folder
          New-Item -ItemType Directory -Path "$PSSCriptRoot/grate"
      }

      # Get version from the url
      $grateVersionNumber = $(([Uri]$downloadUrls[0]).Segments[-2])
      $grateVersionNumber = [Version]$grateVersionNumber.Replace("/", "")

      # Version 1.6.1 was the last version they used the grate-dotnet-tool name for the asset
      if ($grateVersionNumber -le [Version]"1.6.1")
      {
        # Get URL of grate-dotnet-tool
        $downloadUrl = $downloadUrls | Where-Object {$_.Contains("grate-dotnet-tool")}
      }
      else
      {
        if ([Environment]::Is64BitOperatingSystem)
        {
          $osArchitectureBit = "64"  
        }
        else
        {
          $osArchitectureBit = "32"
        }

        if ($isLinux)
        {
          $osType = "linux"
        }
        else
        {
          $osType = "win"
        }
        
        $downloadUrl = $downloadUrls | Where-Object {$_.Contains("grate-$($osType)-x$($osArchitectureBit)-self-contained-$($grateVersionNumber)")}
      }
      
      # Check to see if something was returned
      if ($null -eq $downloadUrl)
      {
      	# Attempt to get nuget package
        Write-Host "An asset with grate-dotnet-tool was not found, attempting to locate nuget package ..."
        $downloadUrl = $downloadUrls | Where-Object {$_.Contains(".nupkg")}
        
        # Check to see if something was returned
        if ($null -eq $downloadUrl)
        {
        	Write-Error "Unable to find appropriate asset for download."
        }
      }

      # Download nuget package
      Write-Output "Downloading $downloadUrl ..."

      # Get download file name
      $downloadFile = $downloadUrl.Substring($downloadUrl.LastIndexOf("/") + 1)

      # Download the file
      Invoke-WebRequest -Uri $downloadUrl -OutFile "$PSSCriptRoot/grate/$downloadFile"

      # Check the extension
      if ($downloadFile.EndsWith(".zip"))
      {
          # Extract the file
          Write-Host "Extracting $downloadFile ..."
          Expand-Archive -Path "$PSSCriptRoot/grate/$downloadFile" -Destination "$PSSCriptRoot/grate"

          # Delete the downloaded .zip
          Remove-Item -Path "$PSSCriptRoot/grate/$downloadFile"

          # Get extracted files
          $extractedFiles = Get-ChildItem -Path "$PSSCriptRoot/grate"

          # Check to see if what was extracted was simply a nuget file
          if ($extractedFiles.Count -eq 1 -and $extractedFiles[0].Extension -eq ".nupkg")
          {
              # Zip file contained a nuget package </facepalm>
              Write-Host "Archive contained a NuGet package, extracting package ..."
              $nugetPackage = $extractedFiles[0]
              $nugetPackage | Rename-Item -NewName $nugetPackage.Name.Replace(".nupkg", ".zip")
              Expand-Archive -Path $nugetPackage.FullName.Replace(".nupkg", ".zip") -Destination "$PSSCriptRoot/grate"
          }
      }

      if ($downloadFile.EndsWith(".nupkg"))
      {
          # Zip file contained a nuget package </facepalm>
          $nugetPackage = Get-ChildItem -Path "$PSSCriptRoot/grate/$($downloadFile)"
          $nugetPackage | Rename-Item -NewName $nugetPackage.Name.Replace(".nupkg", ".zip")
          Expand-Archive -Path "$PSSCriptRoot/grate/$($downloadFile.Replace(".nupkg", ".zip"))" -Destination "$PSSCriptRoot/grate"    
      }
    }
    else
    {
    	Write-Error "No download url returned!"
    }
}



if ([string]::IsNullOrWhitespace($grateExecutable))
{
    # Version 1.6.1 was the last version they used the grate-dotnet-tool name for the asset
    if ($grateVersionNumber -le [Version]"1.6.1")
    {
      # Look for just grate.dll
      $grateExecutable = Get-ChildItem -Path $PSSCriptRoot -Recurse | Where-Object {$_.Name -eq "grate.dll"}
    }
    else
    {
      # Look for executable depending on OS
      if ($isLinux)
      {
        $grateExecutable = Get-ChildItem -Path $PSSCriptRoot -Recurse | Where-Object {$_.Name -eq "grate"} | Where-Object { ! $_.PSIsContainer }
      }
      else
      {
        $grateExecutable = Get-ChildItem -Path $PSSCriptRoot -Recurse | Where-Object {$_.Name -eq "grate.exe"}
      }
    }
    
    # Check for multiple results
    if ($grateExecutable -is [array])
    {
        # choose one that matches highest version of .net
		$dotnetVersions = (dotnet --list-runtimes) | Where-Object {$_ -like "*.NetCore*"}

		$maxVersion = $null
		foreach ($dotnetVersion in $dotnetVersions)
		{
    		$parsedVersion = $dotnetVersion.Split(" ")[1]
    		if ($null -eq $maxVersion -or [System.Version]::Parse($parsedVersion) -gt [System.Version]::Parse($maxVersion))
    		{
        		$maxVersion = $parsedVersion
    		}
		}
        
        $grateExecutable = $grateExecutable | Where-Object {$_.FullName -like "*net$(([System.Version]::Parse($maxVersion).Major))*"}
    }
}

if ([string]::IsNullOrWhitespace($grateExecutable))
{
    # Couldn't find grate
    Write-Error "Couldn't find the grate executable!"
}

# Build the arguments
$grateSwitches = @()

# Update the connection string based on authentication method
switch ($grateAuthenticationMethod)
{
    "awsiam"
    {
        # Region is part of the RDS endpoint, extract
        $region = ($grateServerName.Split("."))[2]

        Write-Host "Generating AWS IAM token ..."
        $grateUserPassword = (aws rds generate-db-auth-token --hostname $grateServerName --region $region --port $grateServerPort --username $grateUserName)       
        $grateUserInfo = "Uid=$grateUserName;Pwd=$grateUserPassword;"

        break
    }
	
    "azuremanagedidentity"
    {
    	# SQL Server driver doesn't assign password
        if ($grateDatabaseServerType -ne "sqlserver")
        {
          # Get login token
          Write-Host "Generating Azure Managed Identity token ..."
          $token = Invoke-RestMethod -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net" -Headers @{"MetaData" = "true"}

          $grateUserPassword = $token.access_token
          $grateUserInfo = "Uid=$grateUserName;Pwd=$grateUserPassword;"
        }
        
        break
    }

    "gcpserviceaccount"
    {
        # Define header
        $header = @{ "Metadata-Flavor" = "Google"}

        # Retrieve service accounts
        $serviceAccounts = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" -Headers $header

        # Results returned in plain text format, get into array and remove empty entries
        $serviceAccounts = $serviceAccounts.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

        # Retreive the specific service account assigned to the VM
        $serviceAccount = $serviceAccounts | Where-Object {$_.Contains("iam.gserviceaccount.com") }

		Write-Host "Generating GCP IAM token ..."
        # Retrieve token for account
        $token = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/$serviceAccount/token" -Headers $header
        $grateUserPassword = $token.access_token
        
        # Append remaining portion of connection string
        $grateUserInfo = "Uid=$grateUserName;Pwd=$grateUserPassword;"
    }


    "usernamepassword"
    {
    	# Append remaining portion of connection string
        $grateUserInfo = "Uid=$grateUserName;Pwd=$grateUserPassword;"

		break    
	}

    "windowsauthentication"
    {
      # Append remaining portion of connection string
	  $grateUserInfo = "integrated security=true;"
      
      # Append username (required for non
      $grateUserInfo += "Uid=$grateUserName;"
    }
    
}

# Configure connnection string based on technology
switch ($grateDatabaseServerType)
{
    "sqlserver"
    {
        # Check to see if port has been defined
        if (![string]::IsNullOrEmpty($grateServerPort))
        {
            # Append to servername
            $grateServerName += ",$grateServerPort"

            # Empty the port
            $grateServerPort = [string]::Empty
        }
    }
    "mariadb"
    {
    	$grateServerPort = "Port=$grateServerPort;Allow User Variables=true;"
    }
    "mysql"
    {
    	# Use the MySQL client
        $grateDatabaseServerType = "mariadb"
        $grateServerPort = "Port=$grateServerPort;Allow User Variables=true;"
    }
    "oracle"
    {
    	# Oracle connection strings are built different than all others
        $grateServerConnectionString = "--connectionstring=`"Data source=$($grateServerName):$($grateServerPort)/$grateDatabaseName;$($grateUserInfo.Replace("Uid", "User Id").Replace("Pwd", "Password")) "
    }
    default
    {
        $grateServerPort = "Port=$grateServerPort;"
    }
}

# Build base connection string
if ([string]::IsNullOrWhitespace($grateServerConnectionString))
{
	$grateServerConnectionString = "--connectionstring=`"Server=$grateServerName;$grateServerPort $grateUserInfo Database=$grateDatabaseName;"
}

# Check for SQL Server and Azure Managed Identity
if (($grateDatabaseServerType -eq "sqlserver") -and ($grateAuthenticationMethod -eq "azuremanagedidentity"))
{
	# Append AD component to connection string
    $grateServerConnectionString += "Authentication=Active Directory Default;"
}

if ($grateSsl -eq $true)
{
	if (($grateDatabaseServerType -eq "mariadb") -or ($grateDatabaseServerType -eq "mysql") -or ($grateDatabaseServerType -eq "postgres"))
    {
    	# Add sslmode
        $grateServerConnectionString += "SslMode=Require;Trust Server Certificate=true;"
    }
    elseif ($grateDatabaseServerType -eq "sqlserver")
    {
    	$grateServerConnectionString += "Trust Server Certificate=true;"
    }
    else
    {
    	Write-Warning "Invalid Database Server Type selection for SSL, ignoring setting."
    }
}

# Add terminating double quote to connection string
$grateServerConnectionString += "`""

$grateSwitches += $grateServerConnectionString

$grateSwitches += "--databasetype=$grateDatabaseServerType"
$grateSwitches += "--silent"

if ([System.Boolean]::Parse($grateDryRun))
{
    $grateSwitches += "--dryrun"
}

if ([System.Boolean]::Parse($grateRecordOutput))
{
    $grateSwitches += "--outputPath=$grateOutputPath"
    
    # Check to see if path exists
    if ((Test-Path -Path $grateOutputPath) -eq $false)
    {
    	# Create folder
        New-Item -Path $grateOutputPath -ItemType "Directory"
    }
}

# Add transaction switch
$grateSwitches += "--transaction=$($grateWithTransaction.ToLower())"

# Add Command Timeout
if (![string]::IsNullOrEmpty($grateCommandTimeout)){
    $grateSwitches += "--commandtimeout=$([int]$grateCommandTimeout)"
}

# Add Baseline switch
if ([System.Boolean]::Parse($grateBaseline)) {
    $grateSwitches += "--baseline"
}

# Add SQL Files Directory parameter
if (![string]::IsNullOrEmpty($grateSqlScriptFolder)) {
    # Add up folder
    $grateSwitches += "--sqlfilesdirectory=$grateSqlScriptFolder"
}

# Add log verbosity flag
if (![string]::IsNullOrEmpty($grateLogVerbosity)) {
    # Add up folder
    $grateSwitches += "--verbosity=$grateLogVerbosity"
}


# Check for version
if (![string]::IsNullOrEmpty($grateVersion))
{
    # Add version
    $grateSwitches += "--version=$grateVersion"
}

# Set grate environment
if (![string]::IsNullOrEmpty($grateEnvironment))
{
    # Add environment
    $grateSwitches += "--environment=$grateEnvironment"
}

# Set grate schema. Especially useful when migrating from RoundhousE
if (![string]::IsNullOrEmpty($grateSchema))
{
    # Add schema
    $grateSwitches += "--schema=$grateSchema"
}

# Display what's going to be run
if (![string]::IsNullOrWhitespace($grateUserPassword))
{
	Write-Host "Executing $($grateExecutable.FullName) with $($grateSwitches.Replace($grateUserPassword, "****"))"
}
else
{
	Write-Host "Executing $($grateExecutable.FullName) with $($grateSwitches)"
}

# Execute grate
if ($grateExecutable.FullName.EndsWith(".dll"))
{
	& dotnet $grateExecutable.FullName $grateSwitches
}
else
{
	& $grateExecutable.FullName $grateSwitches
}

# If the output path was specified, attach artifacts
if ([System.Boolean]::Parse($grateRecordOutput))
{    
    # Zip up output folder content
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    
    $zipFile = "$($OctopusParameters["Octopus.Action.Package[gratePackage].ExtractedPath"])/output.zip"
    
	[System.IO.Compression.ZipFile]::CreateFromDirectory($grateOutputPath, $zipFile)
    New-OctopusArtifact -Path "$zipFile" -Name "output.zip"
}
