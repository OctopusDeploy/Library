$serviceName = $OctopusParameters['ServiceName']
$startupType = $OctopusParameters['StartupType']

if (!$serviceName)
{
    Write-Error "No service name was specified. Please specify the name of the service to set the 'Startup Type'."
    exit -2
}

Write-Output "Setting Startup Type for $serviceName..."

sc.exe config $serviceName start= $startupType

Write-Output "Startup Type for $serviceName set to $startupType."
