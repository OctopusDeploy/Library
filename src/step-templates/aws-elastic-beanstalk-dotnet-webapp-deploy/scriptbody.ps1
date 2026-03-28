$env:Path += ";C:\Program Files (x86)\AWS Tools\Deployment Tool\;C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\"
$AwsDeployConfigFileName = "aws-deploy.config"
$AwsDeployConfigFile = Join-Path $BuildDirectory $AwsDeployConfigFileName
$MSDeployParamsFile = Join-Path $BuildDirectory $MSDeployParamsFilePath
$DeployArchive = Join-Path $MSDeployOutputDirectory.trim().replace(" ", "_") "deploy.zip"

if (!(Test-Path $AwsDeployConfigFile))
{
    # Create an empty, dummy file (not used, awsdeploy params used instead)
    New-Item -path $BuildDirectory -name $AwsDeployConfigFileName -type "file"
}

if (Test-Path $DeployArchive)
{
    # Delete deploy archive if it exists
    Remove-Item $DeployArchive
}

$EscapedBuildDirectory = $BuildDirectory -replace "\\","\\"
$EscapedBuildDirectory = $EscapedBuildDirectory -replace "\.","\."
$MSDeployParamsContent = (Get-Content $MSDeployParamsFile)
$MSDeployParamsContent = $MSDeployParamsContent -replace "{BUILD_DIRECTORY}",$EscapedBuildDirectory
Set-Content $MSDeployParamsFile $MSDeployParamsContent

Write-Host "Creating WebDeploy package file $DeployArchive with the contents of directory $BuildDirectory"
msdeploy.exe -verb:sync `
    -source:iisApp="$BuildDirectory" `
    -dest:package="$DeployArchive" `
    -declareParamFile="$MSDeployParamsFile"

Write-Host "Starting AWSdeploy"
awsdeploy -r -v `
    "-DAWSProfileName=$($ProfileName)" `
    "-DApplication.Name=$($ApplicationName)" `
    "-DEnvironment.Name=$($EnvironmentName)" `
    "-DRegion=$($Region)" `
    "-DUploadBucket=$($UploadBucket)" `
    "-DAWSAccessKey=$($AccessKey)" `
    "-DAWSSecretKey=$($SecretKey)" `
    "-DTemplate=ElasticBeanstalk" `
    "-DDeploymentPackage=$($DeployArchive)" `
    "$AwsDeployConfigFile"

# Sleep to give time to the deployment process to start
Start-Sleep -Seconds 5

$i = 0
$isReady = $FALSE
# Wait no more than 10 minutes for the deployment to finish (or 120 sleeps of 5 seconds)
while ((!$isReady) -and ($i -lt 120)) {
    $i++
    $ebHealth = Get-EBEnvironment -AccessKey "$AccessKey" -SecretKey "$SecretKey" -Region "$Region" -EnvironmentName "$EnvironmentName"

    if ($ebHealth.Status -eq "Ready") {
        Write-Host "Deployment successful."
        $isReady=$TRUE;
    } else {
        Write-Host "Deployment status: $($ebHealth.Status)"
    }
    Start-Sleep -Seconds 5
}

if (!$isReady) {
    Write-Host "Deployment failed. Please check your AWS console."
}