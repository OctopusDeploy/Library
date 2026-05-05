# Define functions
function Get-ModuleInstalled
{
    # Define parameters
    param(
        $PowerShellModuleName
    )

    # Check to see if the module is installed
    if ($null -ne (Get-Module -ListAvailable -Name $PowerShellModuleName))
    {
        # It is installed
        return $true
    }
    else
    {
        # Module not installed
        return $false
    }
}

function Get-NugetPackageProviderNotInstalled
{
	# See if the nuget package provider has been installed
    return ($null -eq (Get-PackageProvider -ListAvailable -Name Nuget -ErrorAction SilentlyContinue))
}

function Install-PowerShellModule
{
    # Define parameters
    param(
        $PowerShellModuleName,
        $LocalModulesPath
    )

	# Check to see if the package provider has been installed
    if ((Get-NugetPackageProviderNotInstalled) -ne $false)
    {
    	# Display that we need the nuget package provider
        Write-Host "Nuget package provider not found, installing ..."
        
        # Install Nuget package provider
        Install-PackageProvider -Name Nuget -Force
    }

	# Save the module in the temporary location
    Write-Host "Saving module $PowerShellModuleName to temporary folder ..."
    Save-Module -Name $PowerShellModuleName -Path $LocalModulesPath -Force
    Write-Host "Save successful!"
}

# Check to see if $IsWindows is available
if ($null -eq $IsWindows)
{
     Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

# Check to see if it's running on Windows
if ($IsWindows)
{
	# Disable the progress bar so downloading files via Invoke-WebRequest are faster
    $ProgressPreference = 'SilentlyContinue'
}

if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Define PowerShell Modules path
$LocalModules = (New-Item "$PWD/modules" -ItemType Directory -Force).FullName
$env:PSModulePath = "$LocalModules$([IO.Path]::PathSeparator)$env:PSModulePath"
$azureModule = "Az.App"

# Get variables
$templateAzureAccountClient = $OctopusParameters['Template.Azure.Account.ClientId']
$templateAzureAccountPassword = $OctopusParameters['Template.Azure.Account.Password']
$templateAzureAccountTenantId = $OctopusParameters['Template.Azure.Account.TenantId']
$templateAzureResourceGroup = $OctopusParameters['Template.Azure.ResourceGroup.Name']
$templateAzureSubscriptionId = $OctopusParameters['Template.Azure.Account.SubscriptionId']
$templateEnvironmentName = $OctopusParameters['Template.ContainerApp.Environment.Name']
$templateAzureLocation = $OctopusParameters['Template.Azure.Location.Name']
$templateAzureContainer = $OctopusParameters['Template.Azure.Container.Image']
$templateAzureContainerIngressPort = $OctopusParameters['Template.Azure.Container.Ingress.Port']
$templateAzureContainerIngressExternal = $OctopusParameters['Template.Azure.Container.ExternalIngress']
$vmMetaData = $null
$secretRef = @()
$templateAzureContainerSecrets = $null
$templateAzureJWTToken = $OctopusParameters['Template.Azure.Account.JWTToken']

if (![string]::IsNullOrWhitespace($OctopusParameters['Template.Azure.Container.Variables']))
{
    $templateAzureContainerEnvVars = ($OctopusParameters['Template.Azure.Container.Variables'] | ConvertFrom-JSON)
}
else
{
	$templateAzureContainerEnvVars = $null
}

if (![string]::IsNullOrWhitespace($OctopusParameters['Template.Azure.Container.Secrets']))
{
    $templateAzureContainerSecrets = ($OctopusParameters['Template.Azure.Container.Secrets'] | ConvertFrom-JSON)
}
else
{
	$templateAzureContainerSecrets = $null
}

$templateAzureContainerCPU = $OctopusParameters['Template.Azure.Container.Cpu']
$templateAzureContainerMemory = $OctopusParameters['Template.Azure.Container.Memory']

# Check for required PowerShell module
Write-Host "Checking for module $azureModule ..."

if ((Get-ModuleInstalled -PowerShellModuleName $azureModule) -eq $false)
{
	# Install the module
    Install-PowerShellModule -PowerShellModuleName $azureModule -LocalModulesPath $LocalModules
}

# Import the necessary module
Write-Host "Importing module $azureModule ..."
Import-Module $azureModule

# Check to see if the account was specified
if (![string]::IsNullOrWhitespace($templateAzureAccountClient))
{
	# Login using the provided account
    Write-Host "Logging in as specified account ..."

    # Check to see if the jtw token was given
    if (![string]::IsNullOrWhitespace($templateAzureJWTToken))
    {
      # Log in with OIDC
      Write-Host "Logging in using OIDC ..."

      
      # Log in
      Connect-AzAccount -FederatedToken $templateAzureJWTToken -ApplicationId $templateAzureAccountClient -Tenant $templateAzureAccountTenantId -Subscription $templateAzureSubscriptionId | Out-Null    
    }

    if (![string]::IsNullOrWhitespace($templateAzureAccountPassword))
    {
        # Log in with Azure Service Principal
        Write-Host "Logging in with Azure Service Principal ..."
        
        # Create credential object for az module
	    $securePassword = ConvertTo-SecureString $templateAzureAccountPassword -AsPlainText -Force
	    $azureCredentials = New-Object System.Management.Automation.PSCredential ($templateAzureAccountClient, $securePassword)  

        Connect-AzAccount -Credential $azureCredentials -ServicePrincipal -Tenant $templateAzureAccountTenantId -Subscription $templateAzureSubscriptionId | Out-Null
    }    
    
    Write-Host "Login successful!"
}
else
{
	Write-Host "Using machine Managed Identity ..."
    $vmMetaData = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01"
    
    Connect-AzAccount -Identity
    
    # Get Identity context
    $identityContext = Get-AzContext
    
    # Set variables
    $templateAzureSubscriptionId = $vmMetaData.compute.subscriptionId
    
    if ([string]::IsNullOrWhitespace($templateAzureAccountTenantId))
    {
    	$templateAzureAccountTenantId = $identityContext.Tenant
    }
    
    Set-AzContext -Tenant $templateAzureAccountTenantId | Out-Null
	Write-Host "Successfully set context for Managed Identity!"
}

# Check to see if the environment name is a / in it
if ($templateEnvironmentName.Contains("/") -ne $true)
{
	# Lookup environment id by name
    Write-Host "Looking up Managed Environment by Name ..."
    $templateEnvironmentName = (Get-AzContainerAppManagedEnv -ResourceGroupName $templateAzureResourceGroup -EnvName $templateEnvironmentName -SubscriptionId $templateAzureSubscriptionId).Id
}

# Build parameter list to pass to New-AzContainerAppTemplateObject
$PSBoundParameters.Add("Image", $OctopusParameters["Octopus.Action.Package[Template.Azure.Container.Image].Image"])
$PSBoundParameters.Add("Name", $OctopusParameters["Template.Azure.Container.Name"])

if (![string]::IsNullOrWhitespace($templateAzureContainerCPU))
{
    $PSBoundParameters.Add("ResourceCpu", "$templateAzureContainerCPU")
}

if (![string]::IsNullOrWhitespace($templateAzureContainerMemory))
{
    $PSBoundParameters.Add("ResourceMemory", "$templateAzureContainerMemory")
}

if ($null -ne $templateAzureContainerEnvVars)
{
    # Loop through list
    $envVars = @()
    foreach ($envVar in $templateAzureContainerEnvVars)
    {
    	$envEntry = @{}
        $envEntry.Add("Name", $envVar.Name)
        
        # Check for specific property
        if ($envVar.SecretRef)
        {
        	$envEntry.Add("SecretRef", $envVar.SecretRef)
        }
        else
        {
        	$envEntry.Add("Value", $envVar.Value)
        }
        
        # Add to collection
        $envVars += $envEntry
    }
    
    $PSBoundParameters.Add("Env", $envVars)
}

if ($null -ne $templateAzureContainerSecrets)
{
	# Loop through list
    foreach ($secret in $templateAzureContainerSecrets)
    {
        # Create new secret object and add to array
        $secretRef += New-AzContainerAppSecretObject -Name $secret.Name -Value $secret.Value
    }
}

# Create new container app
$containerDefinition = New-AzContainerAppTemplateObject @PSBoundParameters
$PSBoundParameters.Clear()

# Define ingress components
if (![string]::IsNullOrWhitespace($templateAzureContainerIngressPort))
{
	$PSBoundParameters.Add("IngressExternal", [System.Convert]::ToBoolean($templateAzureContainerIngressExternal))
    $PSBoundParameters.Add("IngressTargetPort", $templateAzureContainerIngressPort)
}

# Check the image
if ($OctopusParameters["Octopus.Action.Package[Template.Azure.Container.Image].Image"].Contains("azurecr.io"))
{
	# Define local parameters
    $registryCredentials = @{}
    $registrySecret = @{}
    
    # Accessing an ACR repository, configure credentials
    if (![string]::IsNullOrWhitespace($templateAzureAccountClient))
    {

		# Use configured client, name must be lower case
        $registryCredentials.Add("Username", $templateAzureAccountClient)
        $registryCredentials.Add("PasswordSecretRef", "clientpassword")

		$secretRef += New-AzContainerAppSecretObject -Name "clientpassword" -Value $templateAzureAccountPassword
    }
    else
    {
    	# Using Managed Identity
        $registryCredentials.Add("Identity", "system")
        
    }
    
    $registryServer = $OctopusParameters["Octopus.Action.Package[Template.Azure.Container.Image].Image"]
    $registryServer = $registryServer.Substring(0, $registryServer.IndexOf("/"))
    $registryCredentials.Add("Server", $registryServer)
       
    # Add credentials
    $PSBoundParameters.Add("Registry", $registryCredentials)
}

# Define secrets component
if ($secretRef.Count -gt 0)
{
	# Add to parameters
    $PSBoundParameters.Add("Secret", $secretRef)
}

# Create new configuration object
Write-Host "Creating new Configuration Object ..."
$configurationObject = New-AzContainerAppConfigurationObject @PSBoundParameters
$PSBoundParameters.Clear()

# Define parameters
$PSBoundParameters.Add("Name", $OctopusParameters["Template.Azure.Container.Name"])
$PSBoundParameters.Add("TemplateContainer", $containerDefinition)
$PSBoundParameters.Add("ResourceGroupName", $templateAzureResourceGroup)
$PSBoundParameters.Add("Configuration", $configurationObject)


# Check to see if the container app already exists
$containerApps = Get-AzContainerApp -ResourceGroupName $templateAzureResourceGroup

if ($null -eq $containerApps)
{
  $containerApp = $null
}
else
{
  $containerApp = ($containerApps | Where-Object {$_.Name -eq $OctopusParameters["Template.Azure.Container.Name"]})
}

if ($null -eq $containerApp)
{
	# Add parameters required for creating container app
	$PSBoundParameters.Add("EnvironmentId", $templateEnvironmentName)
	$PSBoundParameters.Add("Location", $templateAzureLocation)
	
	# Deploy container
    Write-Host "Creating new container app ..."
	New-AzContainerApp @PSBoundParameters
}
else
{
	Write-Host "Updating existing container app ..."
    Update-AzContainerApp @PSBoundParameters
}
