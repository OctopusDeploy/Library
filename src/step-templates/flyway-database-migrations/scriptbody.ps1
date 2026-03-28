$VerboseActionPreference="Continue"

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

function Test-AddParameterToCommandline
{
	param (
    	$acceptedCommands,
        $selectedCommand,
        $parameterValue,
        $defaultValue,
        $parameterName
    )
    
    if ([string]::IsNullOrWhiteSpace($parameterValue) -eq $true)
    {    	
    	Write-Verbose "$parameterName is empty, returning false"
    	return $false
    }
    
    if ([string]::IsNullOrWhiteSpace($defaultValue) -eq $false -and $parameterValue.ToLower().Trim() -eq $defaultValue.ToLower().Trim())
    {
    	Write-Verbose "$parameterName is matches the default value, returning false"
    	return $false
    }
    
    if ([string]::IsNullOrWhiteSpace($acceptedCommands) -eq $true -or $acceptedCommands -eq "any")
    {
    	Write-Verbose "$parameterName has a value and this is for any command, returning true"
    	return $true
    }
    
    $acceptedCommandArray = $acceptedCommands -split ","
    foreach ($command in $acceptedCommandArray)
    {
    	if ($command.ToLower().Trim() -eq $selectedCommand.ToLower().Trim())
        {
        	Write-Verbose "$parameterName has a value and the current command $selectedCommand matches the accepted command $command, returning true"
        	return $true
        }
    }
    
    Write-Verbose "$parameterName has a value but is not accepted in the current command, returning false"
    return $false
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

# Declaring the path to the NuGet package
$flywayPackagePath = $OctopusParameters["Octopus.Action.Package[Flyway.Package.Value].ExtractedPath"]
$flywayUrl = $OctopusParameters["Flyway.Target.Url"]
$flywayUser = $OctopusParameters["Flyway.Database.User"]
$flywayUserPassword = $OctopusParameters["Flyway.Database.User.Password"]
$flywayCommand = $OctopusParameters["Flyway.Command.Value"]
$flywayLicenseKey = $OctopusParameters["Flyway.License.Key"]
$flywayLicenseEmail = $OctopusParameters["Flyway.Email.Address"]
$flywayLicensePAT = $OctopusParameters["Flyway.PersonalAccessToken"]
$flywayExecutablePath = $OctopusParameters["Flyway.Executable.Path"]
$flywaySchemas = $OctopusParameters["Flyway.Command.Schemas"]
$flywayTarget = $OctopusParameters["Flyway.Command.Target"]
$flywayInfoSinceDate = $OctopusParameters["Flyway.Command.InfoSinceDate"]
$flywayInfoSinceVersion = $OctopusParameters["Flyway.Command.InfoSinceVersion"]
$flywayLicensedEdition = $OctopusParameters["Flyway.License.Version"]
$flywayCherryPick = $OctopusParameters["Flyway.Command.CherryPick"]
$flywayOutOfOrder = $OctopusParameters["Flyway.Command.OutOfOrder"]
$flywaySkipExecutingMigrations = $OctopusParameters["Flyway.Command.SkipExecutingMigrations"]
$flywayPlaceHolders = $OctopusParameters["Flyway.Command.PlaceHolders"]
$flywayBaseLineVersion = $OctopusParameters["Flyway.Command.BaselineVersion"]
$flywayBaselineDescription = $OctopusParameters["Flyway.Command.BaselineDescription"]
$flywayAuthenticationMethod = $OctopusParameters["Flyway.Authentication.Method"]
$flywayLocations = $OctopusParameters["Flyway.Command.Locations"]
$flywayAdditionalArguments = $OctopusParameters["Flyway.Additional.Arguments"]
$flywayStepName = $OctopusParameters["Octopus.Action.StepName"]
$flywayEnvironment = $OctopusParameters["Octopus.Environment.Name"]
$flywayCheckBuildUrl = $OctopusParameters["Flyway.Command.CheckBuildUrl"]
$flywayCheckBuildUsername = $OctopusParameters["Flyway.Database.Check.User"]
$flywayCheckBuildPassword = $OctopusParameters["Flyway.Database.Check.User.Password"]
$flywayBaselineOnMigrate = $OctopusParameters["Flyway.Command.BaseLineOnMigrate"]
$flywaySnapshotFileName = $OctopusParameters["Flyway.Command.Snapshot.FileName"]
$flywayCheckFailOnDrift = $OctopusParameters["Flyway.Command.FailOnDrift"]

if ([string]::IsNullOrWhitespace($flywayLocations))
{
	$flywayLocations = "filesystem:$flywayPackagePath"
}


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
Write-Host "-target: $flywayTarget"
Write-Host "-cherryPick: $flywayCherryPick"
Write-Host "-outOfOrder: $flywayOutOfOrder"
Write-Host "-skipExecutingMigrations: $flywaySkipExecutingMigrations"
Write-Host "-infoSinceDate: $flywayInfoSinceDate"
Write-Host "-infoSinceVersion: $flywayInfoSinceVersion"
Write-Host "-baselineOnMigrate: $flywayBaselineOnMigrate"
Write-Host "-baselineVersion: $flywayBaselineVersion"
Write-Host "-baselineDescription: $flywayBaselineDescription"
Write-Host "-locations: $flywayLocations"
Write-Host "-check.BuildUrl: $flywayCheckBuildUrl"
Write-Host "-check.failOnDrift: $flywayCheckFailOnDrift"
Write-Host "-snapshot.FileName OR check.DeployedSnapshot: $flywaySnapshotFileName"
Write-Host "Additional Arguments: $flywayAdditionalArguments"
Write-Host "placeHolders: $flywayPlaceHolders"
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
if ($flywayCommand -eq "migrate dry run")
{
	$commandToUse = "migrate"
}

if ($flywayCommand -eq "check dry run" -or $flywayCommand -eq "check changes" -or $flywayCommand -eq "check drift")
{
	$commandToUse = "check"
}

$arguments = @(
	$commandToUse    
)

if ($flywayCommand -eq "check dry run")
{
	$arguments += "-dryrun"
}

if ($flywayCommand -eq "check changes")
{
	$arguments += "-changes"
    $arguments += "-dryrun"
}

if ($flywayCommand -eq "check drift")
{
	$arguments += "-drift"
}

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
    	# Add password
        Write-Host "Testing for parameters that can be applied to any command"
        if (Test-AddParameterToCommandline -parameterValue $flywayUser -acceptedCommands "any" -selectedCommand $flywayCommand -parameterName "-user")
        {
            Write-Host "User provided, adding user and password command line argument"
            $arguments += "-user=`"$flywayUser`""
            $arguments += "-password=`"$flywayUserPassword`""
        }
        
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
$arguments += "-locations=`"$flywayLocations`""

if (Test-AddParameterToCommandline -parameterValue $flywaySchemas -acceptedCommands "any" -selectedCommand $flywayCommand -parameterName "-schemas")
{
	Write-Host "Schemas provided, adding schemas command line argument"
	$arguments += "-schemas=`"$flywaySchemas`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywayLicenseKey -acceptedCommands "any" -selectedCommand $flywayCommand -parameterName "-licenseKey")
{
	Write-Host "License key provided, adding -licenseKey command line argument"
    Write-Host "*****WARNING***** Use of the License Key has been deprecated by Redgate and will be removed in future versions, use the Personal Access Token method instead."
	$arguments += "-licenseKey=`"$flywayLicenseKey`""                  
}

if (![string]::IsNullOrWhiteSpace($flywayLicenseEmail) -and ![string]::IsNullOrWhiteSpace($flywayLicensePAT))
{
    if (Test-AddParameterToCommandline -parameterValue $flywayLicensePAT -acceptedCommands "any" -selectedCommand $flywayCommand -parameterName "-token")
    {
        Write-Host "Personal Access Token provided, adding -email and -token command line arguments"
        $arguments += @("-email=`"$flywayLicenseEmail`"", "-token=`"$flywayLicensePAT`"")
    }
}

Write-Host "Finished testing for parameters that can be applied to any command, moving onto command specific parameters"

if (Test-AddParameterToCommandline -parameterValue $flywayCherryPick -acceptedCommands "migrate,info,validate,check" -selectedCommand $flywayCommand -parameterName "-cherryPick")
{
	Write-Host "Cherry pick provided, adding cherry pick command line argument"
	$arguments += "-cherryPick=`"$flywayCherryPick`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywayOutOfOrder -defaultValue "false" -acceptedCommands "migrate,info,validate,check" -selectedCommand $commandToUse -parameterName "-outOfOrder")
{
	Write-Host "Out of order is not false, adding out of order command line argument"
	$arguments += "-outOfOrder=`"$flywayOutOfOrder`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywayPlaceHolders -acceptedCommands "migrate,info,validate,undo,repair,check" -selectedCommand $commandToUse -parameterName "-placeHolders")
{
	Write-Host "Placeholder parameter provided, adding them to the command line arguments"
    
    $placeHolderValueList = @(($flywayPlaceHolders -Split "`n").Trim())
    foreach ($placeHolder in $placeHolderValueList)
    {
    	$placeHolderSplit = $placeHolder -Split "::"
        $placeHolderKey = $placeHolderSplit[0]
        $placeHolderValue = $placeHolderSplit[1]
        Write-Host "Adding -placeHolders.$placeHolderKey = $placeHolderValue to the argument list"
        
        $arguments += "-placeholders.$placeHolderKey=`"$placeHolderValue`""    
    }   	
}

if (Test-AddParameterToCommandline -parameterValue $flywayTarget -acceptedCommands "migrate,info,validate,undo,check" -selectedCommand $commandToUse -parameterName "-target")
{
	Write-Host "Target provided, adding target command line argument"

	if ($flywayTarget.ToLower().Trim() -eq "latest" -and $flywayCommand -eq "undo")
	{
		Write-Host "The current target is latest, but the command is undo, changing the target to be current"
		$flywayTarget = "current"
	}

	$arguments += "-target=`"$flywayTarget`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywaySkipExecutingMigrations -defaultValue "false" -acceptedCommands "migrate" -selectedCommand $flywayCommand -parameterName "-skipExecutingMigrations")
{
	Write-Host "Skip executing migrations is not false, adding skip executing migrations command line argument"
	$arguments += "-skipExecutingMigrations=`"$flywaySkipExecutingMigrations`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywayBaselineOnMigrate -defaultValue "false" -acceptedCommands "migrate" -selectedCommand $flywayCommand -parameterName "-baselineOnMigrate")
{
	Write-Host "Baseline on migrate is not false, adding the baseline on migrate argument"
	$arguments += "-baselineOnMigrate=`"$flywayBaselineOnMigrate`""    
    
    if (Test-AddParameterToCommandline -parameterValue $flywayBaselineVersion -acceptedCommands "migrate" -selectedCommand $flywayCommand -parameterName "-baselineVersion")
    {
    	Write-Host "Baseline version has been specified, adding baseline version argument"
		$arguments += "-baselineVersion=`"$flywayBaselineVersion`""  
    }
}

if (Test-AddParameterToCommandline -parameterValue $flywayBaselineVersion -acceptedCommands "baseline" -selectedCommand $flywayCommand -parameterName "-baselineVersion")
{
	Write-Host "Doing a baseline, adding baseline version and description"
	$arguments += "-baselineVersion=`"$flywayBaselineVersion`""    
    $arguments += "-baselineDescription=`"$flywayBaselineDescription`""    
}

if (Test-AddParameterToCommandline -parameterValue $flywayInfoSinceDate -acceptedCommands "info" -selectedCommand $flywayCommand -parameterName "-infoSinceDate")
{
	Write-Host "Info since date has been provided, adding that to the command line arguments"
	$arguments += "-infoSinceDate=`"$flywayInfoSinceDate`""
}

if (Test-AddParameterToCommandline -parameterValue $flywayInfoSinceVersion -acceptedCommands "info" -selectedCommand $flywayCommand -parameterName "-infoSinceVersion")
{
	Write-Host "Info since version has been provided, adding that to the command line arguments"
	$arguments += "-infoSinceVersion=`"$flywayInfoSinceVersion`""
} 

if (Test-AddParameterToCommandline -parameterValue $flywaySnapshotFileName -acceptedCommands "snapshot" -selectedCommand $commandToUse -parameterName "-snapshot.filename")
{
	Write-Host "Snapshot filename has been provided, adding that to the command line arguments"
    $folderName = Split-Path -Parent $flywaySnapshotFileName
    if ((test-path $folderName) -eq $false)
    {
    	New-Item $folderName -ItemType Directory
    }
    $arguments += "-snapshot.filename=`"$flywaySnapshotFileName`""
}

$snapshotFileNameforCheckProvided = $false
if (Test-AddParameterToCommandline -parameterValue $flywaySnapshotFileName -acceptedCommands "check" -selectedCommand $commandToUse -parameterName "-check.deployedSnapshot")
{
	Write-Host "Snapshot filename has been provided for the check command, adding that to the command line arguments"
    $folderName = Split-Path -Parent $flywaySnapshotFileName
    if ((test-path $folderName) -eq $false)
    {
    	New-Item $folderName -ItemType Directory
    }
    $arguments += "-check.deployedSnapshot=`"$flywaySnapshotFileName`""
    $snapshotFileNameforCheckProvided = $true
}

if ((Test-AddParameterToCommandline -parameterValue $flywayCheckBuildUrl -acceptedCommands "check" -selectedCommand $commandToUse -parameterName "-check.buildUrl") -eq $true -and $snapshotFileNameforCheckProvided -eq $false)
{
	Write-Host "Check build URL has been provided, adding that to the command line arguments"
	$arguments += "-check.buildUrl=`"$flywayCheckBuildUrl`""
}

Write-Host "Checking to see if the check username and password were supplied"
if ((Test-AddParameterToCommandline -parameterValue $flywayCheckBuildUsername -acceptedCommands "check" -selectedCommand $commandToUse -parameterName "-user")  -eq $true -and $snapshotFileNameforCheckProvided -eq $false)
{
	Write-Host "Check User provided, adding check user and check password command line argument"
	$arguments += "-check.buildUser=`"$flywayCheckBuildUsername`""
	$arguments += "-check.buildPassword=`"$flywayCheckBuildPassword`""
}

if (Test-AddParameterToCommandline -parameterValue $flywayCheckFailOnDrift -acceptedCommands "check drift" -selectedCommand $flywayCommand -parameterName "-check.failOnDrift")
{
	Write-Host "Doing a check drift command, adding the fail on drift"
	$arguments += "-check.failOnDrift=`"$flywayCheckFailOnDrift`""
}


Write-Host "Finished checking for command specific parameters, moving onto execution"
$dryRunOutputFile = ""

if ($flywayCommand -eq "migrate dry run")
{
	$dryRunOutputFile = Join-Path $(Get-Location) "dryRunOutput"
    Write-Host "Adding the argument dryRunOutput so Flyway will perform a dry run and not an actual migration."
    $arguments += "-dryRunOutput=`"$dryRunOutputFile`""
}

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

# Display what's going to be run
if (![string]::IsNullOrWhitespace($flywayUserPassword))
{
    $flywayDisplayArguments = $arguments.PSObject.Copy()
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

# Attempt to find driver path for java
$driverPath = (Get-ChildItem -Path (Get-ChildItem -Path $flywayCmd).Directory -Recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -eq "drivers"})

# If found, add driver path to the PATH environment varaible
if ($null -ne $driverPath)
{
	$env:PATH += "$([IO.Path]::PathSeparator)$($driverPath.FullName)"
}

# Adjust call to flyway command based on OS
if ($IsLinux)
{
    & bash $flywayCmd $arguments
}
else
{
    & $flywayCmd $arguments
}

# Check exit code
if ($lastExitCode -ne 0)
{
	# Fail the step
    Write-Error "Execution of Flyway failed!"
}

$currentDate = Get-Date
$currentDateFormatted = $currentDate.ToString("yyyyMMdd_HHmmss")

# Check to see if the dry run variable has a value
if (![string]::IsNullOrWhitespace($dryRunOutputFile))
{     
    $sqlDryRunFile = "$($dryRunOutputFile).sql"
    $htmlDryRunFile = "$($dryRunOutputFile).html"
    
    if (Test-Path $sqlDryRunFile)
    {
    	New-OctopusArtifact -Path $sqlDryRunFile -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted)_dryRunOutput.sql"
    }
    
    if (Test-Path $htmlDryRunFile)
    {
    	New-OctopusArtifact -Path $htmlDryRunFile -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted)_dryRunOutput.html"
    }
}

$reportFile = Join-Path $(Get-Location) "report.html"
    
if (Test-Path $reportFile)
{
  	New-OctopusArtifact -Path $reportFile -Name "$($flywayStepName)_$($flywayEnvironment)_$($currentDateFormatted)_report.html"
}