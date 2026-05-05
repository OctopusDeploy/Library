# Supress info messages written to stderr
Write-Host "##octopus[stderr-progress]"

# Installs the Argo Rollouts plugin
function Install-Plugin
{
# Define parameters
	param ($PluginUri,
           $PluginFilename
    )
    
    # Check for plugin folder
    if ((Test-Path -Path "$PWD/plugins") -eq $false)
    {
		# Create new plugins folder
        New-Item -Path "$PWD/plugins" -ItemType "Directory"
        
        # Add to path
        $env:PATH = "$($PWD)/plugins$([IO.Path]::PathSeparator)" + $env:PATH
    }

	# Download plugin
	Invoke-WebRequest -Uri "$PluginUri" -OutFile "$PWD/plugins/$PluginFilename"

	# Make file executable
    if ($IsLinux)
    {
		# Make it executable
    	chmod +x ./plugins/$PluginFilename
    }
    
    if ($IsWindows)
    {
    	# Update filename to include .exe extension
        Rename-Item -Path "$PWD/plugins/$PluginFilename" -NewName "$PWD/plugins/$($PluginFilename).exe"
    }
}

# When listing plugins, kubectl looks in all paths defined in $env:PATH and will fail if the path does not exist
function Verify-Path-Variable
{
	# Get current path and split into array
    $paths = $env:PATH.Split([IO.Path]::PathSeparator)
    $verifiedPaths = @()
    
    # Loop through paths
    foreach ($path in $paths)
    {
    	# Check for existence
        if ((Test-Path -Path $path) -eq $true)
        {
        	# Add to verified
            $verifiedPaths += $path
        }
    }
    
    # Return verified paths
    return ($verifiedPaths -join [IO.Path]::PathSeparator)
}

function Get-Plugin-Installed
{
	# Define parameters
    param (
    	$PluginName,
        $InstalledPlugins
        )
        
   	$isInstalled = $false
   
	foreach ($plugin in $installedPlugins)
   	{
		if ($plugin -like "$($PluginName)*")
        {
        	$isInstalled = $true
          	break
        }
	}
    
    return $isInstalled
}

# Check to see if $IsWindows is available
if ($null -eq $IsWindows) {
    Write-Host "Determining Operating System..."
    $IsWindows = ([System.Environment]::OSVersion.Platform -eq "Win32NT")
    $IsLinux = ([System.Environment]::OSVersion.Platform -eq "Unix")
}

# Fix ANSI Color on PWSH Core issues when displaying objects
if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

# Check to see if it's running on Windows
if ($IsWindows) {
    # Disable the progress bar so downloading files via Invoke-WebRequest are faster
    $ProgressPreference = 'SilentlyContinue'
}

# Set TLS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

# Verify all PATH variables are avaialable
$env:PATH = Verify-Path-Variable
if ($IsLinux)
{
	$pluginUri = "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
}

if ($IsWindows)
{
	$pluginUri = "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-windows-amd64"
}

try 
{
    # Check to see if plugins are installed
    $pluginList = (kubectl plugin list 2>&1)

    # This is the path that Linux will take
    if ($lastExitCode -ne 0 -and $pluginList.Exception.Message -eq "error: unable to find any kubectl plugins in your PATH") 
    {
        Install-Plugin -PluginUri $pluginUri -PluginFilename "kubectl-argo-rollouts"
    }
    else
    {
        # Parse list
    	$pluginList = $pluginList.Split("`n", [System.StringSplitOptions]::RemoveEmptyEntries)
        
        if ((Get-Plugin-Installed -PluginName "kubectl-argo-rollouts" -InstalledPlugins $pluginList) -eq $false)
        {
        	Install-Plugin -PluginUri $pluginUri -PluginFilename "kubectl-argo-rollouts"
        }
        else
        {
        	Write-Host "Argo Rollout kubectl plugin found ..."
        }
    }    
}
catch
{
	# On Windows, the executable will cause an error if no plugins found so this the path Windows will take
    if ($_.Exception.Message -eq "error: unable to find any kubectl plugins in your PATH")
    {
      Install-Plugin -PluginUri $pluginUri -PluginFilename "kubectl-argo-rollouts"    
    }
    else
    {
    	# Something else happened, we need to surface the error
        throw
    }
}

# Get parameters
$rolloutsName = $OctopusParameters['Argo.Rollout.Name']
$rolloutsNamespace = $OctopusParameters['Argo.Rollout.Namespace']
$rolloutRevision = $OctopusParameters['Argo.Rollout.Revision']

# Create arguments array
$kubectlArguments = @("argo", "rollouts", "undo", $rolloutsName, "--namespace", $rolloutsNamespace)

# Check for revision
if (![string]::IsNullOrWhitespace($rolloutRevision))
{
	# Add argument
    $kubectlArguments += @("--to-revision=$rolloutRevision")
}

# Pause rollout
kubectl $kubectlArguments

if ($lastExitCode -ne 0)
{
	Write-Error "Rollout command failed!"
}