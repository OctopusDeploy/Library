$webSiteName = $OctopusParameters['WebSiteName']
if (! $webSiteName) {
    throw "Web Site Name cannot be empty, please specify the web site to delete"
}

# Helper to run a block with a retry if things go wrong
$maxFailures = 5
$sleepBetweenFailures = Get-Random -minimum 1 -maximum 4
function Execute-WithRetry([ScriptBlock] $command) {
	$attemptCount = 0
	$operationIncomplete = $true

	while ($operationIncomplete -and $attemptCount -lt $maxFailures) {
		$attemptCount = ($attemptCount + 1)

		if ($attemptCount -ge 2) {
			Write-Output "Waiting for $sleepBetweenFailures seconds before retrying..."
			Start-Sleep -s $sleepBetweenFailures
			Write-Output "Retrying..."
		}

		try {
			& $command

			$operationIncomplete = $false
		} catch [System.Exception] {
			if ($attemptCount -lt ($maxFailures)) {
				Write-Output ("Attempt $attemptCount of $maxFailures failed: " + $_.Exception.Message)
			
			}
			else {
			    throw "Failed to execute command"
			}
		}
	}
}

Add-PSSnapin WebAdministration -ErrorAction SilentlyContinue
Import-Module WebAdministration -ErrorAction SilentlyContinue

pushd IIS:\

try {
    Write-Output "Deleting web site $webSiteName"
    $sitePath = ("IIS:\Sites\" + $webSiteName)
    
    Write-Output $sitePath
    
    $site = Get-Item $sitePath -ErrorAction SilentlyContinue
    if (! $site) {
        Write-Output "$webSiteName does not exist"
    }
    else {
        
        Execute-WithRetry {
            $state = Get-WebSiteState $webSiteName
            if($state.Value -eq "Started") {
                Write-Output "Web site is running. Attempting to stop..."
                Stop-WebSite $webSiteName
            }
        }
        
        Write-Output "Attempting to delete $webSiteName..."
        Execute-WithRetry {
            Write-Output "Removing SSL Bindings..."
            #Skipping default binding (Hostname $null) as it will break all sites which depend on this binding (non-SNI enabled sites will be grouped on the default binding! Remove-WebSite can handle this properly.)
            Get-Item 'IIS:\SslBindings\' | Get-ChildItem | select $_.Sites | Where-Object { ($_.Sites -contains $webSiteName) -and ($_.Hostname -ne $null) } | Remove-Item
            Write-Output "Removing Web Bindings..."
            Get-WebBinding -Name $webSiteName | Remove-WebBinding
            Write-Output "Removing web site..."
            Remove-WebSite $webSiteName
        }
    }
} catch [System.Exception] {
    throw ("Failed to execute command" + $_.Exception.Message)
}

popd

Write-Output "IIS Configuration complete"