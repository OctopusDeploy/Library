# Set TLS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

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

<#
 .SYNOPSIS
 Finds the DAC File that you specify

 .DESCRIPTION
 Looks through the supplied PathList array and searches for the file you specify.  It will return the first one that it finds.

 .PARAMETER FileName
 Name of the file you are looking for

 .PARAMETER PathList
 Array of Paths to search through.

 .EXAMPLE
 Find-DacFile -FileName "Microsoft.SqlServer.TransactSql.ScriptDom.dll" -PathList @("${env:ProgramFiles}\Microsoft SQL Server", "${env:ProgramFiles(x86)}\Microsoft SQL Server")
#>
Function Find-DacFile {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string[]]$PathList
    )

    $File = $null

    ForEach($Path in $PathList)
    {
        Write-Debug ("Searching: {0}" -f $Path)

        If (!($File))
        {
            $File = (
                Get-ChildItem $Path -ErrorAction SilentlyContinue -Filter $FileName -Recurse |
                    Sort-Object FullName -Descending |
                    Select-Object -First 1
                )

            If ($File)
            {
                Write-Debug ("Found: {0}" -f $File.FullName)
            }
        }
    }

    Return $File
}


<#
 .SYNOPSIS
 Generates a connection string

 .DESCRIPTION
 Derive a connection string from the supplied variables

 .PARAMETER ServerName
 Name of the server to connect to

 .PARAMETER Database
 Name of the database to connect to

 .PARAMETER UseIntegratedSecurity
 Boolean value to indicate if Integrated Security should be used or not

 .PARAMETER UserName
 User name to use if we are not using integrated security

 .PASSWORD Password
 Password to use if we are not using integrated security

 .PARAMETER EnableMultiSubnetFailover
 Flag as to whether we should enable multi subnet failover

 .EXAMPLE
 Get-ConnectionString -ServerName localhost -UseIntegratedSecurity -Database OctopusDeploy

 .EXAMPLE
 Get-ConnectionString -ServerName localhost -UserName sa -Password ProbablyNotSecure -Database OctopusDeploy
#>
Function Get-ConnectionString {
    Param(
        [Parameter(Mandatory=$True)]
        [string]$ServerName,
        [string]$UserName,
        [string]$Password,
        [string]$Database,
        [string]$AuthenticationType
    )

    $ApplicationName = "OctopusDeploy"
    $connectionString = ("Application Name={0};Server={1}" -f $ApplicationName, $ServerName)

    switch ($AuthenticationType)
    {
    	"AzureADPassword"
        {
            Write-Verbose "Using Azure Active Directory username and password"
            $connectionString += (";Authentication='Active Directory Password';Uid={0};Pwd={1}" -f $UserName, $Password)                
            break
        }
        "AzureADIntegrated"
        {
            Write-Verbose "Using Azure Active Directory integrated"
            $connectionString += (";Authentication='Active Directory Integrated'")                
            break
        }
        "AzureADManaged"
        {
        	Write-Verbose "Using Azure Active Directory managed identity"
            break
        }
        "AzureADServicePrincipal"
        {
             Write-Verbose "Using Azure Active Directory username and password"
            $connectionString += (";Authentication='ActiveDirectoryServicePrincipal';Uid={0};Pwd={1}" -f $UserName, $Password)                
            break       	
        }
        "SqlAuthentication"
        {
            Write-Verbose "Using SQL Authentication username and password"
            $connectionString += (";Uid={0};Pwd={1}" -f $UserName, $Password)                
            break        
        }
        "WindowsIntegrated"
        {
            Write-Verbose "Using integrated security"
            $connectionString += ";Trusted_Connection=True"
            break
        }
    }
    
    if ($EnableMultiSubnetFailover)
    {
        Write-Verbose "Enabling multi subnet failover"
        $connectionString += ";MultisubnetFailover=True"
    }

    If ($Database)
    {
        $connectionString += (";Initial Catalog={0}" -f $Database)
    }

	$connectionString += ";TrustServerCertificate=true;"

    Return $connectionString
}

<#
 .SYNOPSIS
 Will find the full path of a given filename (For dacpac or publish profile)
 .DESCRIPTION
 Will search through an extracted package folder provided as the BasePath and hunt for any matches for the given filename.
 .PARAMETER BasePath
 String value of the root folder to begine the recursive search.
 .PARAMETER FileName
 String value of the name of the file to search for.
 .PARAMETER FileType
 String value of "DacPac" or "PublishProfile" to identify the type of file to search for.
 .EXAMPLE
 Get-DacFilePath -BasePath $ExtractPath -FileName $DACPACPackageName -FileType "DacPac"
#>
function Get-DacFilePath {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$BasePath,

        [parameter(Mandatory=$true)]
        [string]$FileName,

        [parameter(Mandatory=$true)]
        [ValidateSet("DacPac","PublishProfile")]
        [string]$FileType
    )

    # Add file extension for a dacpac if it's missing
    if($FileName.Split(".")[-1] -ne "dacpac" -and $FileType -eq "DacPac"){
        $FileName = "$FileName.dacpac"
    }

    Write-Verbose "Looking for $FileType $FileName in $BasePath."

    $filePath = (Get-ChildItem -Path $BasePath -Recurse -Filter $FileName).FullName

    if(@($filePath).Length -gt 1){
        Write-Warning "Found $(@($filePath).Length) instances of $FileName. Using $($filePath[0])."
        Write-Warning "Multiple paths for $FileName`: $(@($filePath) -join "; ")"
        $filePath = $filePath[0]
    }
    elseif(@($filePath).Length -lt 1 -or $null -eq $filePath){
        Throw "Could not find $FileName."
    }

    return $filePath
}

function Add-SqlCmdVariables
{
	# Get all SqlCmdVariables
    $sqlCmdVariables = $OctopusParameters.Keys -imatch "SqlCmdVariable.*"
    $argumentList = @()
        
	# Check to see if something is there
	if ($null -ne $sqlCmdVariables)
    {
    	Write-Host "Adding SqlCmdVariables ..."
        
		# Loop through the variable collection
        foreach ($sqlCmdVariable in $sqlCmdVariables)
        {
        	# Add variable to the deploy options
            $sqlCmdVariableKey = $sqlCmdVariable.Substring(($sqlCmdVariable.ToLower().IndexOf("sqlcmdvariable.") + "sqlcmdvariable.".Length))
            
            Write-Host "Adding variable: $sqlCmdVariableKey with value: $($OctopusParameters[$sqlCmdVariable])"
            
            $argumentList += ("/variables:{0}={1}" -f $sqlCmdVariableKey, $OctopusParameters[$sqlCmdVariable])
        }
    }
    
    # return the list of variables
    return $argumentList
}

function Add-AdditionalArguments
{
	# Define parameters
    param (
    	$AdditionalArguments
    )
    
    # Define local variables
    $argumentsToAdd = @()
    
    # Check for emmpty or null
    if (![string]::IsNullOrWhitespace($AdditionalArguments))
    {
    	# Split the arguments
    	$argumentsToAdd += $AdditionalArguments.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries).Trim()
    }
    
    # Return list
    return $argumentsToAdd
}

function Get-SqlPackage
{
	# Define local variables
    $workFolder = $OctopusParameters['Octopus.Action.Package[DACPACPackage].ExtractedPath']
    $downloadUrl = ""

	# Check to see if a folder needs to be created
    if((Test-Path -Path "$workFolder/sqlpackage") -eq $false)
    {
        # Create new folder
        New-Item -ItemType Directory -Path "$workFolder/sqlpackage"
    }
    
    Write-Host "Downloading SqlPackage ..."
    
    if ($IsWindows)
    {
    	# Set url
        $downloadUrl = "https://aka.ms/sqlpackage-windows"
    }
    
    if ($IsLinux)
    {
    	# Set url
        $downloadUrl = "https://aka.ms/sqlpackage-linux"
    }
    
    # Download sql package
    if ($PSVersionTable.PSVersion.Major -ge 6)
    {
    	# Download
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$workFolder/sqlpackage/sqlpackage.zip"
    }
    else
    {
    	Invoke-WebRequest -Uri $downloadUrl -OutFile "$workFolder/sqlpackage/sqlpackage.zip" -UseBasicParsing
    }
    
    # Expand the archive
    Write-Host "Extracting .zip ..."
    Expand-Archive -Path "$workFolder/sqlpackage/sqlpackage.zip" -DestinationPath "$workFolder/sqlpackage"
    
    # Add to PATH
    $env:PATH = "$workFolder/sqlpackage$([IO.Path]::PathSeparator)" + $env:PATH
    
    # Make it executable
    if ($IsLinux)
    {
    	& chmod a+x "$workFolder/sqlpackage/sqlpackage"
    }
}

Function Format-OctopusArgument {

    Param(
        [string]$Value
    )

    $Value = $Value.Trim()

    # There must be a better way to do this
    Switch -Wildcard ($Value){

        "True" { Return $True }
        "False" { Return $False }
        "#{*}" { Return $null }
        Default { Return $Value }
    }
}

Function Get-ManagedIdentityToken
{
	# Get the identity token
    Write-Host "Getting Azure Managed Identity token ..."
    $token = $null
    $tokenUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fdatabase.windows.net%2F"
    
    if ($PSVersionTable.PSVersion.Major -ge 6)
    {
    	$token = Invoke-RestMethod -Method GET -Uri $tokenUrl -Headers @{"MetaData" = "true"}
    }
    else
    {
    	$token = Invoke-RestMethod -Method GET -Uri $tokenUrl -Headers @{"MetaData" = "true"} -UseBasicParsing
    }
    
    # Return the token
    return $token.access_token
}

function Invoke-SqlPackage
{
	# Define parameters
    param (
    	$Action,
        $Arguments
    )
    
    # Add the action
    $Arguments += "/Action:$Action"

    # Display what's going to be run
    if (![string]::IsNullOrWhitespace($Password))
    {
        $displayArguments = $Arguments.PSObject.Copy()
        for ($i = 0; $i -lt $displayArguments.Count; $i++)
        {
            if ($null -ne $displayArguments[$i])
            {
                if ($displayArguments[$i].Contains($Password))
                {
                    $DisplayArguments[$i] = $displayArguments[$i].Replace($Password, "****")
                }
            }
        }

        Write-Host "Executing the following command: sqlpackage $displayArguments"
    }
    else 
    {
        Write-Host "Executing the following command: sqlpackage $Arguments"
    }    
    
    & sqlpackage $Arguments

	# Check exit code
	if ($lastExitCode -ne 0)
	{
		# Fail the step
    	Write-Error "Execution failed!"
	}
}

function Validate-Folder
{
	# Define parameters
    param (
    	$TestPath
    )
    
    # Check for folder
    if ((Test-Path -Path $TestPath) -eq $false)
    {
    	# Create the folder
        New-Item -Path "$TestPath" -ItemType "directory"
    }
}

Function Remove-InvalidFileNameChars {

	Param(
		[string]$FileName
	)

	[IO.Path]::GetinvalidFileNameChars() | ForEach-Object { $FileName = $FileName.Replace($_, "_") }
	Return $FileName
}

# Get the supplied parameters
$PublishProfile = $OctopusParameters["DACPACPublishProfile"]
$DACPACReport = Format-OctopusArgument -Value $OctopusParameters["DACPACReport"]
$DACPACScript = Format-OctopusArgument -Value $OctopusParameters["DACPACScript"]
$DACPACDeploy = Format-OctopusArgument -Value $OctopusParameters["DACPACDeploy"]
$DACPACTargetServer = $OctopusParameters["DACPACTargetServer"]
$DACPACTargetDatabase = $OctopusParameters["DACPACTargetDatabase"]
$DACPACAdditionalArguments = $OctopusParameters["DACPACAdditionalArguments"]
$DACPACExeLocation = $OctopusParameters["DACPACExeLocation"]
$DACPACDateTime = ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss"))

$Username = $OctopusParameters["DACPACSQLUsername"]
$Password = $OctopusParameters["DACPACSQLPassword"]
$PackageReferenceName = "DACPACPackage"

$authenticationType = $OctopusParameters["DACPACAuthenticationType"]

$ExtractPathKey = ("Octopus.Action.Package[{0}].ExtractedPath" -f $PackageReferenceName)
$ExtractPath = $OctopusParameters[$ExtractPathKey]

if(!(Test-Path $ExtractPath)) {
    Throw ("The package extraction folder '{0}' does not exist or the Octopus Tentacle does not have permission to access it." -f $ExtractPath)
}

# Get the DACPAC location
$dacpacFolderName = [System.IO.Path]::GetDirectoryName($DACPACPackageName)
$dacpacFileName = [System.IO.Path]::GetFileName($DACPACPackageName)
$DACPACPackagePath = Get-DacFilePath -BasePath ($ExtractPath + ([IO.Path]::DirectorySeparatorChar) + $dacpacFolderName) -FileName $dacpacFileName -FileType "DacPac"

# Invoke the DacPac utility
try
{
	# Declare working variables
    $sqlPackageArguments = @()
    
    # Build arugment list
    $sqlPackageArguments += "/SourceFile:`"$DACPACPackagePath`""
    $sqlPackageArguments += "/TargetConnectionString:`"$(Get-ConnectionString -ServerName $DACPACTargetServer -Database $DACPACTargetDatabase -UserName $UserName -Password $Password -AuthenticationType $AuthenticationType)`""
    
	# Check to see if a publish profile was designated
	If ($PublishProfile){
    	$profileFolderName = [System.IO.Path]::GetDirectoryName($PublishProfile)
        $profileFileName = [System.IO.Path]::GetFileName($PublishProfile)
    	$PublishProfilePath = Get-DacFilePath -BasePath ($ExtractPath + ([IO.Path]::DirectorySeparatorChar) + $profileFolderName) -FileName $profileFileName -FileType "PublishProfile"
    
    	# Add to arguments
    	$sqlPackageArguments += "/Profile:`"$PublishProfilePath`""
	}    
    
    # Check to see if it's using managed identity
    if ($authenticationType -eq "AzureADManaged")
    {
    	# Add access token
        $Password = Get-ManagedIdentityToken
        $sqlPackageArguments += "/AccessToken:$Password"
    }
    
    # Add sqlcmd variables
    $sqlPackageArguments += Add-SqlCmdVariables
    
	# Add addtional arguments
    $sqlPackageArguments += Add-AdditionalArguments -AdditionalArguments $DACPACAdditionalArguments
    
    # Check to see if command timeout was specified
    if (![string]::IsNullOrWhitespace($DACPACCommandTimeout))
    {
    	# Add timeout parameter
        $sqlPackageArguments += "/Properties:CommandTimeout=$DACPACCommandTimeout"
    }
    
    # Check to see if sqlpackage needs to be downloaded
    if ([string]::IsNullOrWhitespace($DACPACExeLocation))
    {
    	# Download and extract sqlpackage
        Get-SqlPackage
    }
    else
    {
    	# Add folder location to path
        $env:PATH = "$([IO.Path]::GetDirectoryName($DACPACExeLocation))$([IO.Path]::PathSeparator)" + $env:PATH
        Write-Host "It is $($env:PATH)"
    }
    
    # Execute the actions
    if ($DACPACReport)
    {
    	$workFolder = "$($OctopusParameters['Octopus.Action.Package[DACPACPackage].ExtractedPath'])/reports"
        $sqlReportArguments = @()
        $reportArtifact = Remove-InvalidFileNameChars -FileName ("{0}.{1}.{2}.{3}" -f $DACPACTargetServer, $DACPACTargetDatabase, $DACPACDateTime, "DeployReport.xml")
        $sqlReportArguments += "/OutputPath:$workFolder/$reportArtifact"
        
        # Validate the folder
        Validate-Folder -TestPath $workFolder
        
        # Execute the action
        Invoke-SqlPackage -Action "DeployReport" -Arguments ($sqlPackageArguments + $sqlReportArguments)
        
        # Attach artifacts
        foreach ($item in (Get-ChildItem -Path $workFolder))
        {
        	# Upload artifact
            New-OctopusArtifact $item.FullName
        }
    }
    
    if ($DACPACScript)
    {
    	$workFolder = "$($OctopusParameters['Octopus.Action.Package[DACPACPackage].ExtractedPath'])/scripts"
        $sqlScriptArguments = @()
        $scriptArtifact = Remove-InvalidFileNameChars -FileName ("{0}.{1}.{2}.{3}" -f $DACPACTargetServer, $DACPACTargetDatabase, $DACPACDateTime, "DeployScript.sql")
        $sqlScriptArguments += "/OutputPath:$workFolder/$scriptArtifact"
        
        # Validate folder
        Validate-Folder -TestPath $workFolder
        
        # Execute the action
        Invoke-SqlPackage -Action "Script" -Arguments ($sqlPackageArguments + $sqlScriptArguments)
        
        # Attach artifacts
        foreach ($item in (Get-ChildItem -Path $workFolder))
        {
        	# Upload artifact
            New-OctopusArtifact $item.FullName
        }        
    }
    
    if ($DACPACDeploy)
    {
    	# Execute action
        Invoke-SqlPackage -Action "Publish" -Arguments $sqlPackageArguments
    }
}
catch
{
    Write-Host $_.Exception.ToString()
    throw;
}
