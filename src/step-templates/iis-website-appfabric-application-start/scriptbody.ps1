Import-Module WebAdministration

$webSiteName = $OctopusParameters['WebSiteName']
$applicationName = $OctopusParameters['ApplicationName']

if (!$webSiteName)
{
    Write-Error "No Website name was specified. Please specify the name of the Website that contains the AppFabric application."
    exit -2
}

if (!$applicationName)
{
    Write-Error "No Application name was specified. Please specify the name of the AppFabric Application contained in the Website."
    exit -2
}

Write-Output "Starting IIS AppFabric application $applicationName in website $webSiteName"
Start-AsApplication $webSiteName $applicationName
