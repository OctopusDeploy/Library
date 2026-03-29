$VerboseActionPreference="Continue"

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

function Get-FlywayExecutablePath
{
	param (
    	$providedPath
    )
    
    if ([string]::IsNullOrWhiteSpace($providedPath) -eq $false)
    {
    	Write-Host "The executable path was provided, testing to see if it is absolute or relative"
		if ([IO.Path]::IsPathRooted($providedPath))
        {
        	Write-Host "The provided path is absolute, using that"
            
        	return $providedPath
        }
        
        Write-Host "The provided path was relative, combining $(Get-Location) with $providedPath"
        return Join-Path $(Get-Location) $providedPath
    }
    
    Write-Host "Checking to see if we are currently running on Linux"
    if ($IsLinux)    
    {
    	Write-Host "Currently running on Linux"
    	Write-Host "Checking to see if flyway was included with the package"
    	if (Test-Path "./flyway")
        {
        	Write-Host "It was, using that version of flyway"
        	return "flyway"
        }
        
        Write-Host "Testing to see if we are on an execution container with /flyway/flyway as the path"
    	if (Test-Path "/flyway/flyway")
        {
        	Write-Host "We are, using /flyway/flyway"
        	return "/flyway/flyway"
        }               
    }
    
    Write-Host "Currently running on Windows"
    
    Write-Host "Testing to see if flyway.cmd was included with the package"
    if (Test-Path ".\flyway.cmd")
    {
    	Write-Host "It was, using that version."
    	return ".\flyway.cmd"
    }
    
    Write-Host "Testing to see if flyway can be found in the env path"
    $flywayExecutable = (Get-Command "flyway" -ErrorAction SilentlyContinue)
    if ($null -ne $flywayExecutable)
    {
    	Write-Host "The flyway folder is part of the environment path"
        return $flywayExecutable.Source
    }
    
    Fail-Step "Unable to find flyway executable.  Please include it as part of the package, or provide the path to it."
}

function Get-ParsedUrl
{
	# Define parameters
    param (
    	$ConnectionUrl
    )
    
    # Remove the 'jdbc:' portion from the $ConnectionUrl parameter
    $ConnectionUrl = $ConnectionUrl.ToLower().Replace("jdbc:", "")
    
    # Parse and return the url
    return [System.Uri]$ConnectionUrl
}

function Execute-FlywayCommand
{
  # Define parameters
  param(
    $BinaryFilePath,
    $CommandArguments
  )

  # Display what's going to be run
  if (![string]::IsNullOrWhitespace($flywayUserPassword))
  {
      $flywayDisplayArguments = $CommandArguments.PSObject.Copy()
      $arrayIndex = 0
      for ($i = 0; $i -lt $flywayDisplayArguments.Count; $i++)
      {
        if ($null -ne $flywayDisplayArguments[$i])
        {
            if ($flywayDisplayArguments[$i].Contains($flywayUserPassword))
            {
                $flywayDisplayArguments[$i] = $flywayDisplayArguments[$i].Replace($flywayUserPassword, "****")
            }
        }
    }

    Write-Host "Executing the following command: $flywayCmd $flywayDisplayArguments"
  }
  else
  {
    Write-Host "Executing the following command: $flywayCmd $arguments"
  }  

  # Adjust call to flyway command based on OS
  if ($IsLinux)
  {
    & bash $BinaryFilePath $CommandArguments
  }
  else
  {
    & $BinaryFilePath $CommandArguments
  }  
}

# Declaring the path to the NuGet package
$flywayPackagePath = $OctopusParameters["Octopus.Action.Package[Flyway.Package.Value].ExtractedPath"]
$flywayUrl = $OctopusParameters["Flyway.Target.Url"]
$flywayUser = $OctopusParameters["Flyway.Database.User"]
$flywayUserPassword = $OctopusParameters["Flyway.Database.User.Password"]
$flywayCommand = $OctopusParameters["Flyway.Command.Value"]
$flywayLicenseEmail = $OctopusParameters["Flyway.Email.Address"]
$flywayLicensePAT = $OctopusParameters["Flyway.PersonalAccessToken"]
$flywayExecutablePath = $OctopusParameters["Flyway.Executable.Path"]
$flywaySchemas = $OctopusParameters["Flyway.Command.Schemas"]
$flywayAuthenticationMethod = $OctopusParameters["Flyway.Authentication.Method"]
$flywayAdditionalArguments = $OctopusParameters["Flyway.Additional.Arguments"]
$flywayStepName = $OctopusParameters["Octopus.Action.StepName"]
$flywayEnvironment = $OctopusParameters["Octopus.Environment.Name"]
$flywayTargetSchema = $OctopusParameters["Flyway.Target.Schema"]
$flywaySourceSchema = $OctopusParameters["Flyway.Source.Schema.Model"]
$flywayExecuteInTransaction = $OctopusParameters["Flyway.Transaction"]
$flywayUndoScript = [System.Convert]::ToBoolean($OctopusParameters["Flyway.Generate.Undo"])


# Logging for troubleshooting
Write-Host "*******************************************"
Write-Host "Logging variables:"
Write-Host " - - - - - - - - - - - - - - - - - - - - -"
Write-Host "PackagePath: $flywayPackagePath"
Write-Host "Flyway Executable Path: $flywayExecutablePath"
Write-Host "Flyway Command: $flywayCommand"
Write-Host "-url: $flywayUrl"
Write-Host "-user: $flywayUser"
Write-Host "-schemas: $flywaySchemas"
Write-Host "Source Schema Model: $flywaySourceSchema"
Write-Host "Target Schema: $flywayTargetSchema"
Write-Host "Execute in transaction: $flywayExecuteInTransaction"
Write-Host "Additional Arguments: $flywayAdditionalArguments"
Write-Host "Generate Undo script: $flywayUndoScript"
Write-Host "*******************************************"

if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

Write-Host "Setting execution location to: $flywayPackagePath"
Set-Location $flywayPackagePath

$flywayCmd = Get-FlywayExecutablePath -providedPath $flywayExecutablePath

$commandToUse = $flywayCommand

$arguments = @()

# Deteremine authentication method
switch ($flywayAuthenticationMethod)
{
	"awsiam"
    {
		# Check to see if OS is Windows and running in a container
        if ($IsWindows -and $env:DOTNET_RUNNING_IN_CONTAINER)
        {
        	throw "IAM Role authentication is not supported in a Windows container."
        }

		# Get parsed connection string url
        $parsedUrl = Get-ParsedUrl -ConnectionUrl $flywayUrl
        
        # Region is part of the RDS endpoint, extract
        $region = ($parsedUrl.Host.Split("."))[2]

		Write-Host "Generating AWS IAM token ..."
		$flywayUserPassword = (aws rds generate-db-auth-token --hostname $parsedUrl.Host --region $region --port $parsedUrl.Port --username $flywayUser)

		$arguments += "-user=`"$flywayUser`""
    	$arguments += "-password=`"$flywayUserPassword`""

		break
    }
	"azuremanagedidentity"
    {
		# Check to see if OS is Windows and running in a container
        if ($IsWindows -and $env:DOTNET_RUNNING_IN_CONTAINER)
        {
        	throw "Azure Managed Identity is not supported in a Windows container."
        }
        
        # SQL Server driver doesn't assign password
        if (!$flywayUrl.ToLower().Contains("jdbc:sqlserver:"))
        {        
          # Get login token
          Write-Host "Generating Azure Managed Identity token ..."
          $token = Invoke-RestMethod -Method GET -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net" -Headers @{"MetaData" = "true"} -UseBasicParsing

          $flywayUserPassword = $token.access_token
          $arguments += "-password=`"$flywayUserPassword`""
          $arguments += "-user=`"$flywayUser`""
        }
        else
        {
            
			# Check to see if the querstring parameter for Azure Managed Identity is present
            if (!$flywayUrl.ToLower().Contains("authentication=activedirectorymsi"))
            {
                # Add the authentication piece to the jdbc url
                if (!$flywayUrl.EndsWith(";"))
                {
                	# Add the separator
                    $flywayUrl += ";"
                }
                
                # Add authentication piece
                $flywayUrl += "Authentication=ActiveDirectoryMSI"
            }
        }
        
        break
    }
    "gcpserviceaccount"
    {
		# Check to see if OS is Windows and running in a container
        if ($IsWindows -and $env:DOTNET_RUNNING_IN_CONTAINER)
        {
        	throw "GCP Service Account authentication is not supported in a Windows container."
        }
    
        # Define header
        $header = @{ "Metadata-Flavor" = "Google"}

        # Retrieve service accounts
        $serviceAccounts = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" -Headers $header -UseBasicParsing

        # Results returned in plain text format, get into array and remove empty entries
        $serviceAccounts = $serviceAccounts.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

        # Retreive the specific service account assigned to the VM
        $serviceAccount = $serviceAccounts | Where-Object {$_.ToLower().Contains("iam.gserviceaccount.com") }

		Write-Host "Generating GCP IAM token ..."
        # Retrieve token for account
        $token = Invoke-RestMethod -Method Get -Uri "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/$serviceAccount/token" -Headers $header -UseBasicParsing
        
        $flywayUserPassword = $token.access_token
        
        $arguments += "-user=`"$flywayUser`""
        $arguments += "-password=`"$flywayUserPassword`""
        #$env:FLYWAY_PASSWORD = $flywayUserPassword
        
        break
    }   
    "usernamepassword"
    {
        Write-Host "User provided, adding user and password command line argument"
        $arguments += "-user=`"$flywayUser`""
        $arguments += "-password=`"$flywayUserPassword`""
        
        break
    }
    "windowsauthentication"
    {
    	# Display to the user they've selected windows authentication.  Though this is dictated by the jdbc url, this is added to make sure the user knows that's what is
        # being used
        Write-Host "Using Windows Authentication"
        
        # Check for integratedauthentication=true in url
        if (!$flywayUrl.ToLower().Contains("integratedsecurity=true"))
        {
        	# Check to see if the connection url ends with a ;
            if (!$flywayUrl.EndsWith(";"))
            {
            	# Add the ;
                $flywayUrl += ";"
            }
            
            $flywayUrl += "integratedSecurity=true;"
        }
        break
    }
}

$arguments += "-url=`"$flywayUrl`""

if (![String]::IsNullOrWhitespace($flywaySchemas))
{
	Write-Host "Schemas provided, adding schemas command line argument"
	$arguments += "-schemas=`"$flywaySchemas`""    
}

if (![string]::IsNullOrWhiteSpace($flywayLicenseEmail) -and ![string]::IsNullOrWhiteSpace($flywayLicensePAT))
{
    Write-Host "Personal Access Token provided, adding -email and -token command line arguments"
    $arguments += @("-email=`"$flywayLicenseEmail`"", "-token=`"$flywayLicensePAT`"")
}

Write-Host "Performing diff of schema model against $($flywayUrl)/$($flywayDatabase) ..."

# Locate schema-model folder
$packageFolders = Get-ChildItem -Path $flywayPackagePath -Recurse | ?{ $_.PSIsContainer } | Where-Object {$_.Name -eq "schema-model"}

if ($packageFolders -is [array])
{
  Write-Error "Multiple 'schema-model' folders found!"
}

$modelFolderPath = $packageFolders.FullName

$arguments += "-environments.$flywayEnvironment.url=$flywayUrl"
$arguments += "-environment=$flywayEnvironment"
$arguments += "-schemaModelLocation=$modelFolderPath"
if (![string]::IsNullOrWhitespace($flywaySourceSchema))
{
  $arguments += "-schemaModelSchemas=$flywaySourceSchema"
}
if (![string]::IsNullOrWhitespace($flywayTargetSchema))
{
  $arguments += "-environments.$flywayEnvironment.schemas=$flywayTargetSchema"
}

# Execute diff
$diffArguments = @("diff")
$diffArguments += $arguments
$diffArguments += "-diff.source=schemaModel"
$diffArguments += "-diff.target=env:$flywayEnvironment"
$diffArguments += "-diff.artifactFilename=$flywayPackagePath/artifact.diff"

Execute-FlywayCommand -BinaryFilePath $flywayCmd -CommandArguments $diffArguments

# Check to see if there's any additional arguments to add
if (![string]::IsNullOrWhitespace($flywayAdditionalArguments))
{
	# Split on space
    $flywayAdditionalArgumentsArray = ($flywayAdditionalArguments.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))

    # Loop through array
    foreach ($newArgument in $flywayAdditionalArgumentsArray)
    {
    	# Add the arguments
    	$arguments += $newArgument
    }
}

# Attempt to find driver path for java
$driverPath = (Get-ChildItem -Path (Get-ChildItem -Path $flywayCmd).Directory -Recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -eq "drivers"})

# If found, add driver path to the PATH environment varaible
if ($null -ne $driverPath)
{
	$env:PATH += "$([IO.Path]::PathSeparator)$($driverPath.FullName)"
}

$currentDate = Get-Date
$currentDateFormatted = $currentDate.ToString("yyyyMMdd_HHmmss")

$prepareArguments = @("prepare")
$prepareArguments += $arguments
$prepareArguments += "-prepare.source=schemaModel"
$prepareArguments += "-prepare.target=env:$flywayEnvironment"
$prepareArguments += "-prepare.artifactFilename=$flywayPackagePath/artifact.diff"
$prepareArguments += "-prepare.scriptFilename=$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql"

if ($flywayUndoScript)
{
  $prepareArguments += "-prepare.undoFilename=$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).undo.sql"
  $prepareArguments += "-prepare.types=`"deploy,undo`""
}

switch($flywayCommand)
{
  "prepare"
  {
    Execute-FlywayCommand -BinaryFilePath $flywayCmd -CommandArguments $prepareArguments
    if ((Test-Path -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql") -eq $true)
    {
      $fileContents = Get-Content -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql"
      Set-OctopusVariable -name "ScriptFile" -value "$fileContents"
      Write-Host "Output variable with script contents: #{Octopus.Action[$flywayStepName].Output.Scriptfile}"

      if ($flywayUndoScript)
      {
        $fileContents = Get-Content -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).undo.sql"
        Set-OctopusVariable -name "UndoScriptFile" -value "$fileContents"
        Write-Host "Output variable with script contents: #{Octopus.Action[$flywayStepName].Output.UndoScriptfile}"
      }
    }

    break
  }
  "check"
  {
    # Create array for check arguments
    $checkArguments = @("check", "-changes", "-check.changesSource=`"schemaModel`"")
    $checkArguments += $arguments

    # Execute command
    Execute-FlywayCommand -BinaryFilePath $flywayCmd -CommandArguments $checkArguments

    # Attach generated report as Octopus Artifact
    if ((Test-Path -Path "$flywayPackagePath/report.html") -eq $true)
    {
      New-OctopusArtifact -Path "$flywayPackagePath/report.html" -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).report.html"     
    }

    break
  }
  "deploy"
  {
    Execute-FlywayCommand -BinaryFilePath $flywayCmd -CommandArguments $prepareArguments # Prepare has to be run first to produce the scripts deploy needs
    if ((Test-Path -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql") -eq $true)
    {
      # Define deploy arguments
      $deployArguments = @("deploy")
      $deployArguments += $arguments
      $deployArguments += "-deploy.scriptFilename=$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql"
      $deployArguments += "-executeInTransaction=$flywayExecuteInTransaction"

      Execute-FlywayCommand -BinaryFilePath $flywayCmd -CommandArguments $deployArguments

      New-OctopusArtifact -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql" -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).sql"

      if ($flywayUndoScript)
      {
        New-OctopusArtifact -Path "$flywayPackagePath/$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).undo.sql" -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted).undo.sql"
      }
    }
    else
    {
      Write-Host "Script file not found!"
    }
  }
}