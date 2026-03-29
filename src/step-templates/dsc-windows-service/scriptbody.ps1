
    $ServicesToManage = $OctopusParameters['Services']
    $ServicesToIgnore = $OctopusParameters['ServicesToIgnore']
    $TimeoutSeconds = $OctopusParameters['TimeoutSeconds']
    $DesiredState = $OctopusParameters['DesiredState']

    # Gather information about the list of services
    $services_status = @{}

    # For each "service to manage" or wildcard specified ...
    $ServicesToManage -split "," |% `
    {
        $service = $_
    
        # ... retrieve all the services that match that name or wildcard ...
        $service_states = Get-Service |? { $_.Name -match $service }
    
        # ... and add them into an array; we use a key/value array so that services only get added to the array once, even if they are
        # matched by multiple wildcard specifications
        $service_states |% { $services_status[$_.Name] = $_.Status }
    }
    
    # For each "service to ignore" or wildcard specified ...
    $ServicesToIgnore -split "," |% `
    {
        $service = $_
        
        # Copy the keys within services_status, since we will need to change services_status as we enumerate them
        $keys = @()
        $services_status.Keys |% { $keys += $_ }
        
        $keys |% `
        {
           $key = $_
 
           if ($key -match $service -and $service -match "[a-z]+")
           {
                $services_status.Remove($_)
           }
        }
    }

    Write-Host "Matched the following set of services, along with their current status:"
    $services_status

    # Now act as required to bring the services to the desired configuration state
    [DateTime]$startTime = [DateTime]::Now
    
    # State to pass to sc
    $state_type = if ($DesiredState -match "Stopped") { "stop" } else { "start" }

	$unaligned_services = ($services_status.Keys |? { $services_status[$_] -notmatch $DesiredState })
	# Attempt to align the remaining services
	$unaligned_services |% `
	{ 
		Write-Host "Attempting to $state_type service: $_"
		Start-Process -FilePath "cmd" -ArgumentList "/c sc.exe $state_type `"$_`""
	}	
   
   while ($startTime.AddSeconds($TimeoutSeconds) -gt [DateTime]::Now)
    {
		# Attempt to align the remaining services
		$unaligned_services |% `
		{ 
			Write-Host "Attempting to $state_type service: $_"
			$services_status[$_] = Get-Service $_ | Select-Object -Property "Status"
		}	
		$unaligned_services = ($services_status.Keys |? { $services_status[$_] -notmatch $DesiredState })
		Write-Host "$([DateTime]::Now): $($unaligned_services.Count) services of $($services_status.Count) not yet at status: $DesiredState"
		
        if ($unaligned_services.Count -eq 0)
        {
            Write-Host "All services now at desired state; exiting"
            exit 0
        }

          
        # Pause for a second
        [System.Threading.Thread]::Sleep(1000)
    }

    throw "Error: not all services reached the desired state within the specified timeframe: $unaligned_services"


