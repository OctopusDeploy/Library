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
$LocalModules = (New-Item "$PWD/Modules" -ItemType Directory -Force).FullName
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
$templateAzureJWTToken = $OctopusParameters['Template.Azure.Account.JWTToken']

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

    # Check to see if jwt token was provided
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
    Connect-AzAccount -Identity | Out-Null
    
    # Get Identity context
    $identityContext = Get-AzContext
    
    # Set variables
    $templateAzureSubscriptionId = $identityContext.Subscription
    
    if ([string]::IsNullOrWhitespace($templateAzureAccountTenantId))
    {
    	$templateAzureAccountTenantId = $identityContext.Tenant
    }
    
    Set-AzContext -Tenant $templateAzureAccountTenantId | Out-Null

	Write-Host "Successfully set context for Managed Identity!"
}

# Check to see if Container App Environment already exists
Write-Host "Getting list of existing environments ..."
$existingEnvironments = Get-AzContainerAppManagedEnv -ResourceGroupName $templateAzureResourceGroup -SubscriptionId $templateAzureSubscriptionId
$managedEnvironment = $null

if (($null -ne $existingEnvironments) -and ($null -ne ($existingEnvironments | Where-Object {$_.Name -eq $templateEnvironmentName})))
{
	Write-Host "Environment $templateEnvironmentName already exists."
    $managedEnvironment = $existingEnvironments | Where-Object {$_.Name -eq $templateEnvironmentName}
}
else
{
	Write-Host "Environment $templateEnvironmentName not found, creating ..."
    $managedEnvironment = New-AzContainerAppManagedEnv -EnvName $templateEnvironmentName -ResourceGroupName $templateAzureResourceGroup -Location $templateAzureLocation -AppLogConfigurationDestination "" # Empty AppLogConfigurationDestination is workaround for properties issue caused by marking this as required
}

# Set output variable
Write-Host "Setting output variable ManagedEnvironmentId to $($managedEnvironment.Id)"
Set-OctopusVariable -name "ManagedEnvironmentId" -value "$($managedEnvironment.Id)"