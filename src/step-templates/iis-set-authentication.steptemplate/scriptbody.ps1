#requires -version 3

function Update-IISSiteAuthentication {
    param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [boolean]$State,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$AuthMethod
    )
    
    # check if WebAdministration module exists on the server
    $cmd = (Get-Command "Get-Website" -errorAction SilentlyContinue)
    if ($null -eq $cmd) {
        throw "The Windows PowerShell snap-in 'WebAdministration' is not installed on this server. Details can be found at https://technet.microsoft.com/en-us/library/ee790599.aspx."
    }
    
    $IISSecurityPath = "/system.WebServer/security/authentication/$AuthMethod"
    $separator = "`r","`n",","
    $IISSites = $sitepath.split($separator, [System.StringSplitOptions]::RemoveEmptyEntries).Trim(' ')

    $IISValidSites = New-Object System.Collections.ArrayList
	foreach ($website in Get-Website) {
        $IISValidSites.Add($website.name)
        foreach ($app in Get-WebApplication -Site $website.name) {
			$path = $website.name + $app.path
			$IISValidSites.Add($path)
		}
	}

    $IISValidSiteNames = $IISValidSites -join ', '

    foreach($Site in $IISSites) {
        $IISSiteAvailable = $IISValidSites | Where-Object { $_ -eq $Site }

        if ($IISSiteAvailable) {
            Set-WebConfigurationProperty -Filter $IISSecurityPath -Name Enabled -Value $State -PSPath IIS:\\ -Location $Site
            Write-Output "$AuthMethod for site '$Site' set successfully to '$State'."
        }
        else {
            Write-Output "The IISSitePath '$Site' cannot be found. The valid sites are $IISValidSiteNames"
            throw "The IISSitePath '$Site' cannot be found. The valid sites are $IISValidSiteNames"
        }
    }
}

if (Test-Path Variable:OctopusParameters) {
    Update-IISSiteAuthentication -State ($AnonymousAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "AnonymousAuthentication"
    Update-IISSiteAuthentication -State ($WindowsAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "WindowsAuthentication"
    Update-IISSiteAuthentication -State ($DigestAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "DigestAuthentication"
}