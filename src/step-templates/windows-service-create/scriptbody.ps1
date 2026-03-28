$serviceName = $OctopusParameters['ServiceName']
$binaryPath = $OctopusParameters['BinaryPath']
$dependsOn = $OctopusParameters['DependsOn']
$displayName = $OctopusParameters['DisplayName']
$startupType = $OctopusParameters['StartupType']
$description = $OctopusParameters['Description']

Write-Output "Creating $serviceName..."

$serviceInstance = Get-Service $serviceName -ErrorAction SilentlyContinue
if ($serviceInstance -eq $null)
{
    New-Service -Name $serviceName -BinaryPathName $binaryPath -DependsOn $dependsOn -DisplayName $displayName -StartupType $startupType -Description $description
    Write-Output "Service $serviceName created."
}
else
{
    Write-Output "The $serviceName already exist."
}
