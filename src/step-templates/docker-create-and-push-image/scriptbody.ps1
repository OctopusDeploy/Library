# Get the parameters.
$appLocation = $OctopusParameters['ApplicationLocation']
$dockerFile = $OctopusParameters['DockerFile']
$imageName = $OctopusParameters['ImageName']
$tag = $OctopusParameters['ImageTag']
$dockerUsername = $OctopusParameters['DockerUsername']
$dockerPassword = $OctopusParameters['DockerPassword']

# Check the parameters.
if (-NOT $dockerUsername) { throw "You must enter a value for 'Username'." }
if (-NOT $dockerPassword) { throw "You must enter a value for 'Password'." }
if (-NOT $imageName) { throw "You must enter a value for 'Image Name'." }
if (-NOT $appLocation) { throw "You must enter a value for 'Application Location'." }

# If the Dockerfile parameter is not empty, save it to the file.
if ($dockerFile) 
{
    Write-Output 'Saving the Dockerfile'
    $path = Join-Path $appLocation 'Dockerfile'
    Set-Content -Path $path -Value $dockerFile -Force
}

# If the tag parameter is empty, set it as latest.
if (-NOT $tag) 
{
    $tag = 'latest'
}

# Prepare the final image name with the tag.
$imageName += ':' + $tag

# Create the docker image
Write-Output 'Building the Docker Image'
docker build -t $imageName $appLocation

# Upload to DockerHub
Write-Output 'Pushing the Docker Image to DockerHub'
docker login -u $dockerUsername -p $dockerPassword
docker push $imageName