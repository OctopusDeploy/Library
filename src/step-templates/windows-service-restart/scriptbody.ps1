$serviceName = $OctopusParameters['ServiceName']
Write-Output "Restarting $serviceName, stopping..."
$serviceInstance = Get-Service $serviceName
restart-service -InputObject $serviceName -Force
$serviceInstance.WaitForStatus('Running','00:01:00')
Write-Output "Service $serviceName started."