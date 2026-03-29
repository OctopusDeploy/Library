try {
	$iisFeature = Get-WindowsFeature Web-WebServer -ErrorAction Stop
	if ($iisFeature -eq $null -or $iisFeature.Installed -eq $false) {
		Write-Error "It looks like IIS is not installed on this server and the deployment is likely to fail."
		Write-Error "Tip: You can use PowerShell to ensure IIS is installed: 'Install-WindowsFeature Web-WebServer'"
		Write-Error "     You are likely to want more IIS features than just the web server. Run 'Get-WindowsFeature *web*' to see all of the features you can install."
		exit 1
	}
} catch {
	Write-Verbose "Call to `Get-WindowsFeature Web-WebServer` failed."
	Write-Verbose "Unable to determine if IIS is installed on this server but will optimistically continue."
}

try {
	Add-PSSnapin WebAdministration -ErrorAction Stop
} catch {
    try {
		 Import-Module WebAdministration -ErrorAction Stop
		} catch {
			Write-Warning "We failed to load the WebAdministration module. This usually resolved by doing one of the following:"
			Write-Warning "1. Install .NET Framework 3.5.1"
			Write-Warning "2. Upgrade to PowerShell 3.0 (or greater)"
			Write-Warning "3. On Windows 2008 you might need to install PowerShell SnapIn for IIS from http://www.iis.net/downloads/microsoft/powershell#additionalDownloads"
			throw ($error | Select-Object -First 1)
    }
}

Get-WebSite