#################################################################################################
# Change source and destination properties
#################################################################################################

# Source
$IspacFilePath = "#{ISPAC_FILE_PATH}"
 
# Destination
$SsisServer =   $OctopusParameters['deploy.dts.server'] 
$FolderName = $OctopusParameters['SSIS_Folder']
$ProjectName = $OctopusParameters['SSIS_Project']

# Environment
$EnvironmentName = $OctopusParameters['Environment_Name']  
$EnvironmentFolderName = $OctopusParameters['SSIS_Folder']


# Replace empty projectname with filename
if (-not $ProjectName)
{
  $ProjectName = [system.io.path]::GetFileNameWithoutExtension($IspacFilePath)
}
# Replace empty Environment folder with project folder
if (-not $EnvironmentFolderName)
{
  $EnvironmentFolderName = $FolderName
}

clear
Write-Host "========================================================================================================================================================"
Write-Host "==                                                         Used parameters                                                                            =="
Write-Host "========================================================================================================================================================"
Write-Host "Ispac File Path        : " $IspacFilePath
Write-Host "SSIS Server            : " $SsisServer
Write-Host "Project Folder Path    : " $FolderName
Write-Host "Project Name           : " $ProjectName
Write-Host "Environment Name       : " $EnvironmentName
Write-Host "Environment Folder Path: " $EnvironmentFolderName
Write-Host "========================================================================================================================================================"
Write-Host ""

###########################
########## ISPAC ##########
###########################
# Check if ispac file exists
if (-Not (Test-Path $IspacFilePath))
{
    Throw  [System.IO.FileNotFoundException] "Ispac file $IspacFilePath doesn't exists!"
}
else
{
    $IspacFileName = split-path $IspacFilePath -leaf
    Write-Host "Ispac file" $IspacFileName "found"
}


############################
########## SERVER ##########
############################
# Load the Integration Services Assembly
Write-Host "Connecting to server $SsisServer "
$SsisNamespace = "Microsoft.SqlServer.Management.IntegrationServices"
[System.Reflection.Assembly]::LoadWithPartialName($SsisNamespace) | Out-Null;

# Create a connection to the server
$SqlConnectionstring = "Data Source=" + $SsisServer + ";Initial Catalog=master;Integrated Security=SSPI;"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection $SqlConnectionstring

# Create the Integration Services object
$IntegrationServices = New-Object $SsisNamespace".IntegrationServices" $SqlConnection

# Check if connection succeeded
if (-not $IntegrationServices)
{
  Throw  [System.Exception] "Failed to connect to server $SsisServer "
}
else
{
   Write-Host "Connected to server" $SsisServer
}


#############################
########## CATALOG ##########
#############################
# Create object for SSISDB Catalog
$Catalog = $IntegrationServices.Catalogs["SSISDB"]

# Check if the SSISDB Catalog exists
if (-not $Catalog)
{
    # Catalog doesn't exists. The user should create it manually.
    # It is possible to create it, but that shouldn't be part of
    # deployment of packages.
    Throw  [System.Exception] "SSISDB catalog doesn't exist. Create it manually!"
}
else
{
    Write-Host "Catalog SSISDB found"
}


############################
########## FOLDER ##########
############################
# Create object to the (new) folder
$Folder = $Catalog.Folders[$FolderName]

# Check if folder already exists
if (-not $Folder)
{
    # Folder doesn't exists, so create the new folder.
    Write-Host "Creating new folder" $FolderName
    $Folder = New-Object $SsisNamespace".CatalogFolder" ($Catalog, $FolderName, $FolderName)
    $Folder.Create()
}
else
{
    Write-Host "Folder" $FolderName "found"
}


#############################
########## PROJECT ##########
#############################
# Deploying project to folder
if($Folder.Projects.Contains($ProjectName)) {
    Write-Host "Deploying" $ProjectName "to" $FolderName "(REPLACE)"
}
else
{
    Write-Host "Deploying" $ProjectName "to" $FolderName "(NEW)"
}
# Reading ispac file as binary
[byte[]] $IspacFile = [System.IO.File]::ReadAllBytes($IspacFilePath)
$Folder.DeployProject($ProjectName, $IspacFile)
$Project = $Folder.Projects[$ProjectName]
if (-not $Project)
{
    # Something went wrong with the deployment
    # Don't continue with the rest of the script
    return ""
}


#################################
########## ENVIRONMENT ##########
#################################
# Check if environment name is filled
if (-not $EnvironmentName)
{
    # Kill connection to SSIS
    $IntegrationServices = $null 

    # Stop the deployment script
    Return "Ready deploying $IspacFileName without adding environment references"
}

# Create object to the (new) folder
$EnvironmentFolder = $Catalog.Folders[$EnvironmentFolderName]

# Check if environment folder exists
if (-not $EnvironmentFolder)
{
  Throw  [System.Exception] "Environment folder $EnvironmentFolderName doesn't exist"
}

# Check if environment exists
if(-not $EnvironmentFolder.Environments.Contains($EnvironmentName))
{
  Throw  [System.Exception] "Environment $EnvironmentName doesn't exist in $EnvironmentFolderName "
}
else
{
    # Create object for the environment
    $Environment = $Catalog.Folders[$EnvironmentFolderName].Environments[$EnvironmentName]

    if ($Project.References.Contains($EnvironmentName, $EnvironmentFolderName))
    {
        Write-Host "Reference to" $EnvironmentName "found"
    }
    else
    {
        Write-Host "Adding reference to" $EnvironmentName
        $Project.References.Add($EnvironmentName, $EnvironmentFolderName)
        $Project.Alter() 
    }
}


########################################
########## PROJECT PARAMETERS ##########
########################################
$ParameterCount = 0
# Loop through all project parameters
foreach ($Parameter in $Project.Parameters)
{
    # Get parameter name and check if it exists in the environment
    $ParameterName = $Parameter.Name
    if ($ParameterName.StartsWith("CM.","CurrentCultureIgnoreCase")) 
    { 
        # Ignoring connection managers 
    } 
    elseif ($ParameterName.StartsWith("INTERN_","CurrentCultureIgnoreCase")) 
    { 
        # Optional:
        # Internal parameters are ignored (where name starts with INTERN_) 
        Write-Host "Ignoring Project parameter" $ParameterName " (internal use only)" 
    } 
    elseif ($Environment.Variables.Contains($Parameter.Name))
    {
        $ParameterCount = $ParameterCount + 1
        Write-Host "Project parameter" $ParameterName "connected to environment"
        $Project.Parameters[$Parameter.Name].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $Parameter.Name)
        $Project.Alter()
    }
    else
    {
        # Variable with the name of the project parameter is not found in the environment
        # Throw an exeception or remove next line to ignore parameter
        Throw  [System.Exception]  "Project parameter $ParameterName doesn't exist in environment"
    }
}
Write-Host "Number of project parameters mapped:" $ParameterCount


########################################
########## PACKAGE PARAMETERS ##########
########################################
$ParameterCount = 0
# Loop through all packages
foreach ($Package in $Project.Packages)
{
    # Loop through all package parameters
    foreach ($Parameter in $Package.Parameters)
    {
        # Get parameter name and check if it exists in the environment
        $PackageName = $Package.Name
        $ParameterName = $Parameter.Name 
        if ($ParameterName.StartsWith("CM.","CurrentCultureIgnoreCase")) 
        { 
            # Ignoring connection managers 
        } 
        elseif ($ParameterName.StartsWith("INTERN_","CurrentCultureIgnoreCase")) 
        { 
            # Optional:
            # Internal parameters are ignored (where name starts with INTERN_) 
            Write-Host "Ignoring Package parameter" $ParameterName " (internal use only)" 
        } 
        elseif ($Environment.Variables.Contains($Parameter.Name))
        {
            $ParameterCount = $ParameterCount + 1
            Write-Host "Package parameter" $ParameterName "from package" $PackageName "connected to environment"
            $Package.Parameters[$Parameter.Name].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $Parameter.Name)
            $Package.Alter()
        }
        else
        {
            # Variable with the name of the package parameter is not found in the environment
            # Throw an exeception or remove next line to ignore parameter
            Throw  [System.Exception]  "Package parameter $ParameterName from package $PackageName doesn't exist in environment"
        }
    }
}
Write-Host "Number of package parameters mapped:" $ParameterCount


###########################
########## READY ##########
###########################
# Kill connection to SSIS
$IntegrationServices = $null 


Return "Ready deploying $IspacFileName "