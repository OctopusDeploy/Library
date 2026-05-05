$envname = "#{Octopus.Environment.Name}"
$serverurl = "#{if Octopus.Web.ServerUri}#{Octopus.Web.ServerUri}#{else}#{Octopus.Web.BaseUrl}#{/if}"

$headers = @{"X-Octopus-ApiKey"="$apikey"}
$putHeaders = @{"X-HTTP-Method-Override"="PUT"; "X-Octopus-ApiKey"="$apikey"}

function Test-SpacesApi {
	Write-Verbose "Checking API compatibility";
	$rootDocument = Invoke-WebRequest "$serverurl/api" -Headers $headers -Method Get -UseBasicParsing | ConvertFrom-Json;
    if($rootDocument.Links -ne $null -and $rootDocument.Links.Spaces -ne $null) {
    	Write-Verbose "Spaces API found"
    	return $true;
    }
    Write-Verbose "Pre-spaces API found"
    return $false;
}

if(Test-SpacesApi) {
	$spaceId = $OctopusParameters['Octopus.Space.Id'];
    if([string]::IsNullOrWhiteSpace($spaceId)) {
        throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which could indicate you do not have the correct permissions.";
    }
	$baseApiUrl = "/api/$spaceId" ;
} else {
	$baseApiUrl = "/api" ;
}

$environments = Invoke-RestMethod "$serverurl$baseApiUrl/environments/all" -Headers $headers -Method Get
$theEnvironment = $environments | ? { $_.Name -eq $envname }

$machines = Invoke-RestMethod "$serverurl$baseApiUrl/machines/all" -Headers $headers -Method Get
$theMachine = $machines | ? { $_.Name -eq $machineName }

$accounts = Invoke-RestMethod "$serverurl$baseApiUrl/accounts/all" -Headers $headers -Method Get
$theAccount = $accounts | ? { $_.Name -eq $accountname }

if (!($theMachine.Name -eq $machineName))
{
	#this returns a MachineResource, but we need to post a DeploymentTargetResource which requires environments and roles
	$discovered = Invoke-RestMethod "$serverurl$baseApiUrl/machines/discover?host=$hostdetails&type=Ssh" -Headers $headers -Method Get
    $discovered.Endpoint.AccountId = $theAccount.Id
    $discovered.Name = $machineName
	$discovered | add-member -Name "Roles" -value @($role) -MemberType NoteProperty
    $discovered | add-member -Name "EnvironmentIds" -value @($theEnvironment.Id) -MemberType NoteProperty
	
    $registerStatus = Invoke-RestMethod "$serverurl$baseApiUrl/machines" -Headers $headers -Method Post -Body ($discovered | ConvertTo-Json -Depth 10)
    
    If ($registerStatus.Status -eq "Online")
    {
        Write-Output "$registerStatus.Name is Successfully Registered"
    }
    else
    {
        Write-Warning "$hostdetails had issues, Please check Environments Page"
    }
}
else
{
    Write-Output "Machine with name $machineName already exists with the status $($theMachine.Status)" 
}