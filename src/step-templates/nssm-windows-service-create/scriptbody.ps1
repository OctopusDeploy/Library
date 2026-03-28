$serviceStopStepAdded = $OctopusParameters['ServiceStopStepAdded']
$serviceName = $OctopusParameters['ServiceNameValue']
$displayName = $OctopusParameters['ServiceDisplayNameValue']
$startupType = $OctopusParameters['StartupTypeValue']
$description = $OctopusParameters['ServiceDescriptionValue']
$serviceExecutable = $OctopusParameters['ServiceExecutableValue']
$serviceExecutableArgs = $OctopusParameters['serviceExecutableArgsValue']
$serviceAppDirectory = $OctopusParameters['ServiceAppDirectoryValue']
$serviceUserAccount = $OctopusParameters['serviceUserAccountValue']
$serviceUserPassword = $OctopusParameters['serviceUserPasswordValue']
$dependsOn = $OctopusParameters['DependsOnValue']
$serviceErrorLogFile = $OctopusParameters['serviceErrorLogFileValue']
$serviceOutputLogFile = $OctopusParameters['serviceOutputLogFileValue']
$nssmExecutable = $OctopusParameters['NSSMExecutableValue']

if($serviceStopStepAdded -ne 'True'){
    Write-Host Please add a step to stop the windows service as the first step!
    Write-Host If already added, make sure to check the checkbox - Step to stop service added as first step? - in NSSM Windows Service Setup
    return
}

Write-Host Installing service $serviceName -foreground "green"
Write-Host "NSSM path" $serviceAppDirectory
Write-Host $serviceName
Write-Host $serviceExecutable
Write-Host $serviceExecutableArgs
Write-Host $serviceAppDirectory
Write-Host $serviceErrorLogFile
Write-Host $serviceOutputLogFile
Write-Host $serviceUserAccount
Write-Host $serviceUserPassword

push-location
Set-Location $serviceAppDirectory

$service = Get-Service $serviceName -ErrorAction SilentlyContinue

if($service) {
    Write-host service $service.Name is $service.Status
    Write-Host Removing $serviceName service   
    if($service.Status -ne 'Stopped'){
        &$nssmExecutable stop $serviceName
    }
    &$nssmExecutable remove $serviceName confirm
}

Write-Host Installing $serviceName as a service
&$nssmExecutable install $serviceName $serviceExecutable $serviceExecutableArgs

if($displayName){
    &$nssmExecutable set $serviceName DisplayName $displayName
} 

if($startupType){
    &$nssmExecutable set $serviceName Start $startupType
}

if($description){
    &$nssmExecutable set $serviceName Description $description
}

if($dependsOn){
    &$nssmExecutable set $serviceName DependOnService $dependsOn
}

# setting log file 
if($serviceErrorLogFile){
    &$nssmExecutable set $serviceName AppStderr $serviceErrorLogFile
    &$nssmExecutable set $serviceName AppStderrCreationDisposition 2
}

if($serviceOutputLogFile){
    &$nssmExecutable set $serviceName AppStdout $serviceOutputLogFile
    &$nssmExecutable set $serviceName AppStdoutCreationDisposition 2
}

# setting app directory
if($serviceAppDirectory) {
    Write-host setting app directory to $serviceAppDirectory -foreground "green"
    &$nssmExecutable set $serviceName AppDirectory $serviceAppDirectory
}

# setting user account
if($serviceUserAccount -And $serviceUserPassword) {
    &$nssmExecutable set $serviceName ObjectName $serviceUserAccount $serviceUserPassword
}

#start service right away
&$nssmExecutable start $serviceName
pop-location