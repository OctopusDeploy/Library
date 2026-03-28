$baseUri = $OctopusParameters['#{if Octopus.Web.ServerUri}Octopus.Web.ServerUri#{else}Octopus.Web.BaseUrl#{/if}']
$reqheaders = @{"X-Octopus-ApiKey" = $Consolidate_ApiKey }
$putReqHeaders = @{"X-HTTP-Method-Override" = "PUT"; "X-Octopus-ApiKey" = $Consolidate_ApiKey }

$remWhiteSpace = [bool]::Parse($Consolidate_RemoveWhitespace)
$deDupe = [bool]::Parse($Consolidate_Dedupe)
$reverse = ($Consolidate_Order -eq "Oldest")

# Get details we'll need
$projectId = $OctopusParameters['Octopus.Project.Id']
$thisReleaseNumber = $OctopusParameters['Octopus.Release.Number']
$lastSuccessfulReleaseId = $OctopusParameters['Octopus.Release.CurrentForEnvironment.Id']
$lastSuccessfulReleaseNumber = $OctopusParameters['Octopus.Release.CurrentForEnvironment.Number']

function Test-SpacesApi {
	Write-Verbose "Checking API compatibility";
	$rootDocument = Invoke-WebRequest "$baseUri/api" -Headers $reqHeaders -UseBasicParsing | ConvertFrom-Json;
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

# Get all previous releases to this environment
$releaseUri = "$baseUri$baseApiUrl/projects/$projectId/releases"
try {
    $allReleases = Invoke-WebRequest $releaseUri -Headers $reqheaders -UseBasicParsing | ConvertFrom-Json
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -ne 404) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.Io.StreamReader($result);
        $responseBody = $reader.ReadToEnd();
        throw "Error occurred: $responseBody"
    }
}

# Find and aggregate release notes
$aggregateNotes = @()

Write-Host "Finding all release notes between the last successful release: $lastSuccessfulReleaseNumber and this release: $thisReleaseNumber"
foreach ($rel in $allReleases.Items) {
    if ($rel.Id -ne $lastSuccessfulReleaseId) {
        Write-Host "Found release notes for $($rel.Version)"
        $theseNotes = @()
        #split into lines
        $lines = $rel.ReleaseNotes -split "`n"
        foreach ($line in $lines) {
            if (-not $remWhitespace -or -not [string]::IsNullOrWhiteSpace($line)) {
                if (-not $deDupe -or -not $aggregateNotes.Contains($line)) {
                    $theseNotes = $theseNotes + $line
                }
            }
        }
        if ($reverse) {
            $aggregateNotes = $theseNotes + $aggregateNotes
        } else {
            $aggregateNotes = $aggregateNotes + $theseNotes
        }
    } else {
        break
    }
}
$aggregateNotesText = $aggregateNotes -join "`n`n"

# Get the current release
$releaseUri = "$baseUri$baseApiUrl/projects/$projectId/releases/$thisReleaseNumber"
try {
    $currentRelease = Invoke-WebRequest $releaseUri -Headers $reqheaders -UseBasicParsing | ConvertFrom-Json
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -ne 404) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.Io.StreamReader($result);
        $responseBody = $reader.ReadToEnd();
        throw "Error occurred: $responseBody"
    }
}

# Update the release notes for the current release
$currentRelease.ReleaseNotes = $aggregateNotesText
Write-Host "Updating release notes for $thisReleaseNumber`:`n`n"
Write-Host $aggregateNotesText
try {
    $releaseUri = "$baseUri$baseApiUrl/releases/$($currentRelease.Id)"
    $currentReleaseBody = $currentRelease | ConvertTo-Json -Depth 10
    $result = Invoke-WebRequest $releaseUri -Method Post -Headers $putReqHeaders -Body $currentReleaseBody -UseBasicParsing | ConvertFrom-Json
} catch {
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.Io.StreamReader($result);
    $responseBody = $reader.ReadToEnd();
    Write-Host $responseBody
    throw "Error occurred: $responseBody"
}