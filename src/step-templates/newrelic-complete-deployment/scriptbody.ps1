# Minimum PowerShell version for ConvertTo-Json is 3

Add-Type -AssemblyName System.Web

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$apiKey = $OctopusParameters['ApiKey']
$user = $OctopusParameters['User']
$appId = $OctopusParameters['AppId']

#https://octopus.com/docs/deployment-process/variables/system-variables
$releaseNumber = $OctopusParameters['Octopus.Release.Number']
$releaseNotes = $OctopusParameters['Octopus.Release.Notes']
$machineName = $OctopusParameters['Octopus.Machine.Name']
$projectName = $OctopusParameters['Octopus.Project.Name']
$deploymentLink = $OctopusParameters['Octopus.Web.DeploymentLink']

## --------------------------------------------------------------------------------------
## Helpers
## --------------------------------------------------------------------------------------
# Helper for validating input parameters
function Validate-Parameter([string]$foo, [string[]]$validInput, $parameterName) {
  Write-Host "${parameterName}: $foo"
  if (! $foo) {
    throw "No value was set for $parameterName, and it cannot be empty"
  }

  if ($validInput) {
    if (! $validInput -contains $foo) {
      throw "'$input' is not a valid input for '$parameterName'"
    }
  }
}

## --------------------------------------------------------------------------------------
## Configuration
## --------------------------------------------------------------------------------------
Validate-Parameter $apiKey -parameterName "Api Key"

if (!$appId) {
  Write-Host "NewRelic Deploy - AppId has not been set yet. Skipping call to API."
  exit 0
}

if ($appId -eq 0) {
  Write-Host "NewRelic Deploy - AppId has been set to zero. Skipping call to API."
  exit 0
}

$userText = $((" by user $user", "")[!$user])
Write-Host ("NewRelic Deploy - Notify deployment{0} - App {1} - Revision {2}" -f $userText, $appId, $revision)


# https://rpm.newrelic.com/api/explore/application_deployments/create?application_id=1127348
$deployment = New-Object -TypeName PSObject
$deployment | Add-Member -MemberType NoteProperty -Name "user" -Value $user
$deployment | Add-Member -MemberType NoteProperty -Name "revision" -Value $releaseNumber
$deployment | Add-Member -MemberType NoteProperty -Name "changelog" -Value $releaseNotes
$deployment | Add-Member -MemberType NoteProperty -Name "description" -Value "Octopus deployment of $projectName to $machineName. ($deploymentLink)"

$deploymentContainer = New-Object -TypeName PSObject
$deploymentContainer | Add-Member -MemberType NoteProperty -Name "deployment" -Value $deployment

$post = $deploymentContainer | ConvertTo-Json
Write-Debug $post

# in production, we need to
#Create a URI instance since the HttpWebRequest.Create Method will escape the URL by default.
$URL = "https://api.newrelic.com/v2/applications/$appId/deployments.json"
$URI = New-Object System.Uri($URL,$true)

#Create a request object using the URI
$request = [System.Net.HttpWebRequest]::Create($URI)
$request.Method = "POST"
$request.Headers.Add("X-Api-Key","$apiKey");
$request.ContentType = "application/json"

#Build up a nice User Agent
$request.UserAgent = $(
"{0} (PowerShell {1}; .NET CLR {2}; {3})" -f $UserAgent,
$(if($Host.Version){$Host.Version}else{"1.0"}),
[Environment]::Version,
[Environment]::OSVersion.ToString().Replace("Microsoft Windows ", "Win")
)
$ReturnCode = 0
try {
  Write-Host "Posting data to $URL"
  #Create a new stream writer to write the xml to the request stream.
  $stream = New-Object IO.StreamWriter $request.GetRequestStream()
  $stream.AutoFlush = $True
  $PostStr = [System.Text.Encoding]::UTF8.GetBytes($Post)
  $stream.Write($PostStr, 0,$PostStr.length)
  $stream.Close()

  #Make the request and get the response
  $response = $request.GetResponse()

  if ([int]$response.StatusCode -eq 201) {
    Write-Host "NewRelic Deploy - API called succeeded - HTTP $($response.StatusCode)."
  } else {
    Write-Host "NewRelic Deploy - API called failed - HTTP $($response.StatusCode)."
    $ReturnCode = 1
  }
  $response.Close()
} catch {
  $ErrorMessage = $_.Exception.Message
  $res = $_.Exception.Response
  Write-Host "NewRelic Deploy - API called failed - $ErrorMessage"
  $ReturnCode = 1
}
exit $ReturnCode
