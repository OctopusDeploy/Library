# Configure template

# Set TLS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

# Disable progress bar for PowerShell
$ProgressPreference = 'SilentlyContinue'

# Downloads and extracts liquibase to the work folder
Function Get-Liquibase
{
    # Define parameters
    param ($Version) 

	$repositoryName = "liquibase/liquibase"

    # Check to see if version wasn't specified
    if ([string]::IsNullOrEmpty($Version))
    {
        # Get the latest version download url
        $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object {$_.EndsWith(".zip")})
    }
    else
    {
    	$downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $Version | Where-Object {$_.EndsWith(".zip")})
    }

    # Check for download folder
    if ((Test-Path -Path "$PSSCriptRoot\liquibase") -eq $false)
    {
        # Create the folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot\liquibase"
    }

    # Download the zip file
    Write-Output "Downloading Liquibase from $downloadUrl ..."
    $liquibaseZipFile = "$PSScriptroot\liquibase\$($downloadUrl.Substring($downloadUrl.LastIndexOf("/")))"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $liquibaseZipFile -UseBasicParsing
    

    # Extract package
    Write-Output "Extracting Liqbuibase ..."
    Expand-Archive -Path $liquibaseZipFile -DestinationPath "$PSSCriptRoot\liquibase"
}

# Downloads and extracts Java to the work folder, then adds the location of java.exe to the $env:PATH variabble so it can be called
Function Get-Java
{
    # Check to see if a folder needs to be created
    if((Test-Path -Path "$PSScriptRoot\jdk") -eq $false)
    {
        # Create new folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot\jdk"
    }

    # Download java
    Write-Output "Downloading Java ... "
    Invoke-WebRequest -Uri "https://download.java.net/java/GA/jdk14.0.2/205943a0976c4ed48cb16f1043c5c647/12/GPL/openjdk-14.0.2_windows-x64_bin.zip" -OutFile "$PSScriptroot\jdk\openjdk-14.0.2_windows-x64_bin.zip" -UseBasicParsing

    # Extract
    Write-Output "Extracting Java ... "
    Expand-Archive -Path "$PSScriptroot\jdk\openjdk-14.0.2_windows-x64_bin.zip" -DestinationPath "$PSSCriptRoot\jdk"

    # Get Java executable
    $javaExecutable = Get-ChildItem -Path "$PSScriptRoot\jdk" -Recurse | Where-Object {$_.Name -eq "java.exe"}

    # Add path to current session
    $env:PATH += ";$($javaExecutable.Directory)"
}

# Gets download url of latest release with an asset
Function Get-LatestVersionDownloadUrl
{
    # Define parameters
    param(
    	$Repository,
        $Version
    )
    
    # Define local variables
    $releases = "https://api.github.com/repos/$Repository/releases"
    
    # Get latest version
    Write-Host "Determining latest release ..."
    
    $tags = (Invoke-WebRequest $releases -UseBasicParsing | ConvertFrom-Json)
    
    if ($null -ne $Version)
    {
    	$tags = ($tags | Where-Object {$_.name.EndsWith($Version)})
    }

    # Find the latest version with a downloadable asset
    foreach ($tag in $tags)
    {
        if ($tag.assets.Count -gt 0)
        {
            return $tag.assets.browser_download_url
        }
    }

    # Return the version
    return $null
}

# Finds the specified changelog file
Function Get-ChangeLog
{
    # Define parameters
    param ($FileName)
    
    # Find file
    $fileReference = (Get-ChildItem -Path $OctopusParameters["Octopus.Action.Package[liquibaseChangeSet].ExtractedPath"] -Recurse | Where-Object {$_.Name -eq $FileName})

    # Check to see if something weas returned
    if ($null -eq $fileReference)
    {
        # Not found
        Write-Error "$FileName was not found in $PSScriptRoot or subfolders."
    }

    # Return the reference
    return $fileReference
}

# Downloads the appropriate JDBC driver
Function Get-DatabaseJar
{
    # Define parameters
    param ($DatabaseType)

    # Declare local variables
    $driverPath = ""

    # Check to see if a folder needs to be created
    if((Test-Path -Path "$PSScriptRoot\DatabaseDriver") -eq $false)
    {
        # Create new folder
        New-Item -ItemType Directory -Path "$PSSCriptRoot\DatabaseDriver" | Out-Null
    }

    # Download the driver for the selected type
    switch ($DatabaseType)
    {
        "MariaDB"
        {
            # Download MariaDB driver
            Write-Host "Downloading MariaDB driver ..."
            $driverPath = "$PSScriptroot\DatabaseDriver\mariadb-java-client-2.6.2.jar"
            Invoke-WebRequest -Uri "https://downloads.mariadb.com/Connectors/java/connector-java-2.6.2/mariadb-java-client-2.6.2.jar" -OutFile $driverPath -UseBasicParsing
             
            break
        }
        "MongoDB"
        {
        	# Set repo name
            $repositoryName = "liquibase/liquibase-mongodb"
            
            # Download MongoDB driver
            Write-Host "Downloading Maven MongoDB driver ..."
            $driverPath = "$PSScriptroot\DatabaseDriver\mongo-java-driver-3.12.7.jar"
            Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/mongodb/mongo-java-driver/3.12.7/mongo-java-driver-3.12.7.jar" -Outfile $driverPath -UseBasicParsing
            
            if ([string]::IsNullOrEmpty($liquibaseVersion))
            {
            	# Get the latest version for the extension
            	$downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName | Where-Object {$_.EndsWith(".jar")})
           	}
            else
            {
            	# Download version matching extension
                $downloadUrl = (Get-LatestVersionDownloadUrl -Repository $repositoryName -Version $liquibaseVersion | Where-Object {$_.EndsWith(".jar")})
            }
                        
			Write-Host "Downloading MongoDB Liquibase extension from $downloadUrl ..."
            $extensionPath = "$PSScriptroot\$($downloadUrl.Substring($downloadUrl.LastIndexOf("/")))"
            
            Invoke-WebRequest -Uri $downloadUrl -Outfile $extensionPath -UseBasicParsing
                        
            # Make driver path null
            $driverPath = "$driverPath;$extensionPath"
            
            break
        }
        "MySQL"
        {
            # Download MariaDB driver
            Write-Host "Downloading MySQL driver ..."
            Invoke-WebRequest -Uri "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.21.zip" -OutFile "$PSScriptroot\DatabaseDriver\mysql-connector-java-8.0.21.zip" -UseBasicParsing

            # Extract package
            Write-Host "Extracting MySQL driver ..."
            Expand-Archive -Path "$PSScriptroot\DatabaseDriver\mysql-connector-java-8.0.21.zip" -DestinationPath "$PSSCriptRoot\DatabaseDriver"

            # Find driver
            $driverPath = (Get-ChildItem -Path "$PSScriptRoot\DatabaseDriver" -Recurse | Where-Object {$_.Name -eq "mysql-connector-java-8.0.21.jar"}).FullName

            break
        }
        "Oracle"
        {
            # Download Oracle driver
            Write-Host "Downloading Oracle driver ..."
            $driverPath = "$PSScriptroot\DatabaseDriver\ojdbc10.jar"
            Invoke-WebRequest -Uri "https://download.oracle.com/otn-pub/otn_software/jdbc/211/ojdbc11.jar" -OutFile $driverPath -UseBasicParsing

            break
        }
        "SqlServer"
        {
            # Download Microsoft driver
            Write-Host "Downloading Sql Server driver ..."
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2137600" -OutFile "$PSScriptroot\DatabaseDriver\sqljdbc_8.4.0.0_enu.zip" -UseBasicParsing

            # Extract package
            Write-Host "Extracting SqlServer driver ..."
            Expand-Archive -Path "$PSScriptroot\DatabaseDriver\sqljdbc_8.4.0.0_enu.zip" -DestinationPath "$PSSCriptRoot\DatabaseDriver"

            # Find driver
            $driverPath = (Get-ChildItem -Path "$PSSCriptRoot\DatabaseDriver" -Recurse | Where-Object {$_.Name -eq "mssql-jdbc-8.4.1.jre14.jar"}).FullName

			break
        }
        "PostgreSQL"
        {
            # Download PostgreSQL driver
            Write-Host "Downloading PostgreSQL driver ..."
            $driverPath = "$PSScriptroot\DatabaseDriver\postgresql-42.2.12.jar"
            Invoke-WebRequest -Uri "https://jdbc.postgresql.org/download/postgresql-42.2.12.jar" -OutFile $driverPath -UseBasicParsing

            break
        }
        default
        {
            # Display error
            Write-Error "Unknown database type: $DatabaseType."
        }
    }

    # Return the driver location
    return $driverPath
}

# Returns the driver name for the liquibase call
Function Get-DatabaseDriverName
{
    # Define parameters
    param ($DatabaseType)

    # Declare local variables
    $driverName = ""

    # Download the driver for the selected type
    switch ($DatabaseType)
    {
        "MariaDB"
        {
            $driverName = "org.mariadb.jdbc.Driver"
            break
        }
        "MongoDB"
        {
        	$driverName = $null
            break
        }
        "MySQL"
        {
            $driverName = "com.mysql.cj.jdbc.Driver"
            break
        }
        "Oracle"
        {
            $driverName = "oracle.jdbc.OracleDriver"
            break
        }
        "SqlServer"
        {
            $driverName = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
            break
        }
        "PostgreSQL"
        {
            $driverName = "org.postgresql.Driver"
            break
        }
        default
        {
            # Display error
            Write-Error "Unkonwn database type: $DatabaseType."
        }
    }

    # Return the driver location
    return $driverName
}

# Returns the connection string formatted for the database type
Function Get-ConnectionUrl
{
    # Define parameters
    param ($DatabaseType, 
    	$ServerPort, 
        $ServerName, 
        $DatabaseName, 
        $QueryStringParameters)

    # Define local variables
    $connectioUrl = ""

    # Download the driver for the selected type
    switch ($DatabaseType)
    {
        "MariaDB"
        {
            $connectionUrl = "jdbc:mariadb://{0}:{1}/{2}"
            break
        }
        "MongoDB"
        {
        	$connectionUrl = "mongodb://{0}:{1}/{2}"            
            break
        }
        "MySQL"
        {
            $connectionUrl = "jdbc:mysql://{0}:{1}/{2}"
            break
        }
        "Oracle"
        {
            $connectionUrl = "jdbc:oracle:thin:@{0}:{1}:{2}"
            break
        }
        "SqlServer"
        {
            $connectionUrl = "jdbc:sqlserver://{0}:{1};database={2};"
            break
        }
        "PostgreSQL"
        {
            $connectionUrl = "jdbc:postgresql://{0}:{1}/{2}"
            break
        }
        default
        {
            # Display error
            Write-Error "Unkonwn database type: $DatabaseType."
        }
    }

    if (![string]::IsNullOrEmpty($QueryStringParameters))
    {
        if ($QueryStringParameters.StartsWith("?") -eq $false)
        {
            # Add the question mark
            $connectionUrl += "?"
        }
        $connectionUrl += "$QueryStringParameters"
    }

    # Return the url
    return ($connectionUrl -f $ServerName, $ServerPort, $DatabaseName)
}

# Create array for arguments
$liquibaseArguments = @()

# Check for license key
if (![string]::IsNullOrEmpty($liquibaseProLicenseKey))
{
	# Add key to arguments
    $liquibaseArguments += "--liquibaseProLicenseKey=$liquibaseProLicenseKey"
}

# Find Change log
$changeLogFile = (Get-ChangeLog -FileName $liquibaseChangeLogFileName)
$liquibaseArguments += "--changeLogFile=$($changeLogFile.Name)"

# Check to see if it needs to be downloaed to machine
if ($liquibaseDownload -eq $true)
{
    # Download and extract liquibase
    Get-Liquibase -Version $liquibaseVersion -DownloadFolder $workingFolder

    # Download and extract java and add it to PATH environment variable
    Get-Java

    # Get the driver
    $driverPath = Get-DatabaseJar -DatabaseType $liquibaseDatabaseType

	if (![string]::IsNullOrEmpty($driverPath))
    {
    	# Add to arguments
    	$liquibaseArguments += "--classpath=$driverPath"
    }
}
else
{
    if (![string]::IsNullOrEmpty($liquibaseClassPath))
    {
    	$liquibaseArguments += "--classpath=$liquibaseClassPath"
    }
}

# Check to see if liquibase path has been defined
if ([string]::IsNullOrEmpty($liquibaseExecutablePath))
{
    # Assign root
    $liquibaseExecutablePath = $PSSCriptRoot
}

# Get the executable location
$liquibaseExecutable = Get-ChildItem -Path $liquibaseExecutablePath -Recurse | Where-Object {$_.Name -eq "liquibase.bat"}

# Add path to current session
$env:PATH += ";$($liquibaseExecutable.Directory)"

# Check to make sure it was found
if ([string]::IsNullOrEmpty($liquibaseExecutable))
{
    # Could not find the executable
    Write-Error "Unable to find liquibase.bat in $PSScriptRoot or subfolders."
}

# Add argument for driver
#$databaseDriver = Get-DatabaseDriverName -DatabaseType $liquibaseDatabaseType
#if (![string]::IsNullOrEmpty($databaseDriver))
#{
#	$liquibaseArguments += "--driver=$databaseDriver"
#}

# Add connection Url
$connectionUrl = Get-ConnectionUrl -DatabaseType $liquibaseDatabaseType -ServerPort $liquibaseServerPort -ServerName $liquibaseServerName -DatabaseName $liquibaseDatabaseName -QueryStringParameters $liquibaseQueryStringParameters
$liquibaseArguments += "--url=$connectionUrl"

# Add Username and password
$liquibaseArguments += "--username=$liquibaseUsername"
$liquibaseArguments += "--password=`"$liquibasePassword`""

# Set the location to where the file is
Set-Location -Path $changeLogFile.Directory

# Check to see if it should run or just report
if ($liquibaseReport -eq $true)
{
    # Set error action preference - updateSQL writes to stderr so this is to prevent errors from showing up
    $ErrorActionPreference = "SilentlyContinue"
    
    # Add just report
    $liquibaseArguments += "updateSQL"
    
    # Execute liquibase
    $liquibaseProcess = Start-Process -FilePath $liquibaseExecutable.FullName -ArgumentList $liquibaseArguments -RedirectStandardError "$PSScriptRoot\stderr.txt" -RedirectStandardOutput "$PSScriptRoot\ChangeSet.sql" -Passthru -Wait
	    
    # Display standard error
    foreach ($line in (Get-Content -Path "$PSScriptRoot\stderr.txt"))
    {
    	# Display
        Write-Host "$line"
    }
    
    # Check exit code
    if ($liquibaseProcess.ExitCode -eq 0)
    {
    	# Attach artifact
        New-OctopusArtifact -Path "$PSScriptRoot\ChangeSet.sql" -Name "ChangeSet.sql"
    }
}
else
{
    $liquibaseArguments += "update"
    & $liquibaseExecutable.FullName $liquibaseArguments
}

