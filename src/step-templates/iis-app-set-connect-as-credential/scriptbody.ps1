# Import the WebAdministration module
Import-Module WebAdministration

# Get reference to the site
$iisSite = Get-IISSite | Where-Object {$_.Name -ieq $IISSiteName}

# Check to make sure the site was found
if ($null -eq $iisSite)
{
	# Throw an error
    throw "$IISSiteName was not found."
}

# Check to see if $IISApplicationName starts with a /
if ($IISApplicationName.StartsWith("/"))
{
	# Remove the beginning slash
    $IISApplicationName = $IISApplicationName.SubString(1)
}

# Get reference to the application
$application = $iisSite.Applications | Where-Object {$_.Path -ieq "/$IISApplicationName"}

# Check to see if the application was found
if ($null -eq $application)
{
	# Throw an error
    throw "$IISApplicationName was not found."
}

# retrieve existing values
$currentUserName = Get-WebConfigurationProperty "system.applicationHost/sites/site[@name='$($iisSite.Name)']/application[@path='$($application.Path)']/virtualDirectory[@path='/']" -name username
$currentPassword = Get-WebConfigurationProperty "system.applicationHost/sites/site[@name='$($iisSite.Name)']/application[@path='$($application.Path)']/virtualDirectory[@path='/']" -name password

# Check the value of $ApplicationUserName
if ([string]::IsNullOrEmpty($ApplicationUserName))
{
    # Ensure $ApplicationUserName is an empty string
    $ApplicationUserName = [string]::Empty
}

# Check the value of $ApplicationPassword
if ([string]::IsNullOrEmpty($ApplicationUserPassword) -or $ApplicationUserName.EndsWith('$')) # Usernames ending in $ are an indication that an MSA is being used
{
	# Ensure $ApplicationPassword is empty string
    $ApplicationPassword = [string]::Empty
}

# Compare username values
if ($ApplicationUserName -ne $currentUserName.Value)
{
	# Display message
    Write-Output "Updating username for $IISSiteName/$IISApplicationName to $ApplicationUserName Connect As property"
    
	# Update the property
    Set-WebConfigurationProperty "system.applicationHost/sites/site[@name='$($iisSite.Name)']/application[@path='$($application.Path)']/virtualDirectory[@path='/']" -name username -value "$ApplicationUserName"
}
else
{
	# Display message
    Write-Output "User already set to $ApplicationUserName for $IISSiteName/$IISApplicationName Connect As property"
}

# Compare password values
if ($ApplicationUserPassword -ne $currentPassword.Value)
{
    # Display message
    Write-Output "Updating password for $IISSiteName/$IISApplicationName Connect As property"
    
    # Set password property
	Set-WebConfigurationProperty "system.applicationHost/sites/site[@name='$($iisSite.Name)']/application[@path='$($application.Path)']/virtualDirectory[@path='/']" -name password -value "$ApplicationUserPassword"
}
else
{
	# Display message
    Write-Output "Password does not need updating for $IISSiteName/$IISApplicationName Connect As property"
}
