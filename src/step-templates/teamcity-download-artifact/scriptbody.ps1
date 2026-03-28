# Expected parameters:
#  $TeamCityHost     - The domain name and optional port (teamcity.mycompany.com:8080) of the TeamCity build server.
#  $TeamCityUsername - The TeamCity username.
#  $TeamCityPassword - The TeamCity password.
#  $BuildType        - The unique identifier of the TeamCity build configuration.
#  $BranchName       - The name of the branch.
#  $ArtifactName     - The filename of the artifact.
#  $OutputLocation   - The name of the folder where the artifact will be downloaded.

$secure_password = ConvertTo-SecureString $TeamCityPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($TeamCityUsername, $secure_password)

$resource_identifier = "buildType:$BuildType,branch:$BranchName"

$source = "http://$TeamCityHost/httpAuth/app/rest/builds/$resource_identifier/artifacts/content/$ArtifactName"
$destination = "$OutputLocation\$Artifactname"

Invoke-WebRequest $source -OutFile $destination -Credential $credential