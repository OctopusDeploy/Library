# Load IIS module:
Import-Module WebAdministration

# Get WebSite Name
$webSiteName = $OctopusParameters['webSiteName']
# Get the number of retries
$retries = $OctopusParameters['webSiteCheckRetries']
# Get the number of attempts
$delay = $OctopusParameters['webSiteCheckDelay']

# Check if exists
if(Test-Path IIS:\Sites\$webSiteName) {

    # Stop Website if not already stopped
    if ((Get-WebSiteState $webSiteName).Value -ne "Stopped") {
        Write-Output "Stopping IIS Website $webSiteName"
        Stop-WebSite $webSiteName
    
        $state = (Get-WebSiteState $webSiteName).Value
        $counter = 1
        
        # Wait for the Website to the "Stopped" before proceeding
        do{ 
            $state = (Get-WebSiteState $webSiteName).Value
            Write-Output "$counter/$retries Waiting for IIS Website $webSiteName to shut down completely. Current status: $state"
            $counter++
            Start-Sleep -Milliseconds $delay
        }
        while($state -ne "Stopped" -and $counter -le $retries)  
        
        # Throw an error if the Website is not stopped
        if($counter -gt $retries) { 
            throw "Could not shut down IIS Website $webSiteName. `nTry to increase the number of retries ($retries) or delay between attempts ($delay milliseconds)." }
    }
}
else {
    Write-Output "IIS Website $webSiteName doesn't exist"
}