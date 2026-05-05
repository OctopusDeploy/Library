$version = $OctopusParameters['Version']
$url = 'https://api.elmah.io/v3/deployments?api_key=' + $OctopusParameters['ApiKey']
$body = @{
  version = $version
  description = $OctopusReleaseNotes
  userName = $OctopusParameters['Octopus.Deployment.CreatedBy.Username']
  userEmail = $OctopusParameters['Octopus.Deployment.CreatedBy.EmailAddress']
  logId = $OctopusParameters['LogId']
}
Try {
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls
  Invoke-RestMethod -Method Post -Uri $url -Body $body
}
Catch {
  Write-Error $_.Exception.Message -ErrorAction Continue
}