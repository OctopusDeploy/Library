#TFS
$instance = $OctopusParameters["tfsInstance"]
$collection = $OctopusParameters["tfsCollection"]
$project = $OctopusParameters["tfsProject"]
$PAT = $OctopusParameters["tfsPat"]
$pathquery = $OctopusParameters["tfsPathQuery"]

#Octopus
$octopusAPIKey = $OctopusParameters['octopusAPIKey']
$baseUri = $OctopusParameters['#{if Octopus.Web.ServerUri}Octopus.Web.ServerUri#{else}Octopus.Web.BaseUrl#{/if}']
$octopusProjectId = $OctopusParameters['Octopus.Project.Id']
$thisReleaseNumber = $OctopusParameters['Octopus.Release.Number']

write-host "Instance: $($instance)"
write-host "collection: $($collection)"
write-host "project: $($project)"
write-host "baseUri: $($baseUri)"
write-host "projectId: $($projectId)"
write-host "thisReleaseNumber: $($thisReleaseNumber)"
write-host "TFS path: $($pathquery)"

#Create HEADERS
$bytes = [System.Text.Encoding]::ASCII.GetBytes($PAT)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers = @{ }
$headers.Add("Authorization", $basicAuthValue)
$headers.Add("Accept","application/json")
$headers.Add("Content-Type","application/json")

$reqheaders = @{"X-Octopus-ApiKey" = $octopusAPIKey }
$putReqHeaders = @{"X-HTTP-Method-Override" = "PUT"; "X-Octopus-ApiKey" = $octopusAPIKey }

function Test-SpacesApi {
	Write-Verbose "Checking API compatibility";
	$rootDocument = Invoke-WebRequest "$baseUri/api" -Headers $reqheaders -UseBasicParsing | ConvertFrom-Json;
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
        throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which isn't expected - please reach out to our support team at https://help.octopus.com if you encounter this error.";
    }
	$baseApiUrl = "/api/$spaceId" ;
} else {
	$baseApiUrl = "/api" ;
}

# Get the current release
$releaseUri = "$baseUri$baseApiUrl/projects/$octopusProjectId/releases/$thisReleaseNumber"
write-host "Release uri $($releaseUri)"
try {
    $currentRelease = Invoke-RestMethod $releaseUri -Headers $reqheaders -UseBasicParsing 
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -ne 404) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.Io.StreamReader($result);
        $responseBody = $reader.ReadToEnd();
        throw "Error occurred: $responseBody"
    }
}

if(![string]::IsNullOrWhiteSpace($currentRelease.ReleaseNotes)){
	write-host "Release notes already filled in. $($currentRelease.ReleaseNotes)"
    Set-OctopusVariable -name "ReleaseNotes" -value $releaseNotes
	exit;
}


#Get projectid
$url = "http://$($instance)/tfs/$($collection)/$($projectId)/_apis/projects/$($project)?&includeCapabilities=false&includeHistory=false&api-version=2.2"
write-host "Invoking url= $($url)"
$projectresponse = Invoke-RestMethod $url -Method GET -Headers $headers

$projectid = $projectresponse.id
write-host "projectid $($projectid)"

#Get the ID of the query to execute
$queryResult = Invoke-RestMethod "http://$($instance)/tfs/$($collection)/$($projectId)/_apis/$($pathquery)?$depth=1&api-version=2.2" -Method GET -Headers $headers
write-host "queryResult $($queryResult)"

#https://{instance}/DefaultCollection/[{project}/]_apis/wit/wiql/{id}?api-version={version}
$queryResult = Invoke-RestMethod "http://$($instance)/tfs/$($collection)/$($projectId)/_apis/wit/wiql/$($queryResult.Id)?api-version=2.2" -Method GET -Headers $headers

Write-Host "Found $($queryResult.workItems.Count) number of workitems for query: ReleaseNotes$($releaseTag)"

$releaseNotes = "**Work Items:**"


if($queryResult.workItems.Count -eq 0)
{
	Write-Host "No work items for release"
	$releaseNotes = "`n no new work items"
}
else
{
	#Create a list of ids
	$ids = [string]::Join("%2C", ($queryResult.workItems.id))

	#Get all the work items
	$workItems = Invoke-RestMethod  "http://$($instance)/tfs/$($collection)/_apis/wit/workItems?ids=$($ids)&fields=System.Title" -Method GET -Headers $headers

	foreach($workItem in $workItems.value)
	{
		#Add line for each work item
		$releaseNotes = $releaseNotes + "`n* [$($workItem.id)] (http://$($instance)/tfs/$($collection)/9981e67f-b27c-4628-b5cf-fba1d327aa07/_workitems/edit/$($workItem.id)) : $($workItem.fields.'System.Title')"
	}

}



# Update the release notes for the current release
$currentRelease.ReleaseNotes = $releaseNotes 
write-host "Release notes $($currentRelease.ReleaseNotes)"
Write-Host "Updating release notes for $thisReleaseNumber`:`n`n"
try {
    $releaseUri = "$baseUri$baseApiUrl/releases/$($currentRelease.Id)"
    write-host "Release uri $($releaseUri)"
    $currentReleaseBody = $currentRelease | ConvertTo-Json
    write-host "Current release body $($currentReleaseBody)"
    $result = Invoke-RestMethod $releaseUri -Method Post -Headers $putReqHeaders -Body $currentReleaseBody -UseBasicParsing
	write-host "result $($result)"
} catch {
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.Io.StreamReader($result);
    $responseBody = $reader.ReadToEnd();
    Write-Host "error $($responseBody)"
    throw "Error occurred: $responseBody"
}

Set-OctopusVariable -name "ReleaseNotes" -value $releaseNotes
