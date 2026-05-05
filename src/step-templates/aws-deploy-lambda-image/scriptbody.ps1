$ErrorActionPreference = "Stop";

$functionName = $OctopusParameters["AWS.Lambda.FunctionName"] 
$functionRole = $OctopusParameters["AWS.Lambda.FunctionRole"]
$functionRunTime = $OctopusParameters["AWS.Lambda.Runtime"]
$functionMemorySize = $OctopusParameters["AWS.Lambda.MemorySize"]
$functionDescription = $OctopusParameters["AWS.Lambda.Description"]
$functionVPCSubnetId = $OctopusParameters["AWS.Lambda.VPCSubnetIds"]
$functionVPCSecurityGroupId = $OctopusParameters["AWS.Lambda.VPCSecurityGroupIds"]
$functionEnvironmentVariables = $OctopusParameters["AWS.Lambda.EnvironmentVariables"]
$functionEnvironmentVariablesKey = $OctopusParameters["AWS.Lambda.EnvironmentVariablesKey"]
$functionTimeout = $OctopusParameters["AWS.Lambda.FunctionTimeout"]
$functionTags = $OctopusParameters["AWS.Lambda.Tags"]
$functionFileSystemConfig = $OctopusParameters["AWS.Lambda.FileSystemConfig"]
$functionDeadLetterConfig = $OctopusParameters["AWS.Lambda.DeadLetterConfig"]
$functionTracingConfig = $OctopusParameters["AWS.Lambda.TracingConfig"]
$functionVersionNumber = $OctopusParameters["Octopus.Action.Package[AWS.Lambda.Package].PackageVersion"]
$functionPublishOption = $OctopusParameters["AWS.Lambda.Publish"]

$functionReleaseNumber = $OctopusParameters["Octopus.Release.Number"]
$functionRunbookRun = $OctopusParameters["Octopus.RunbookRun.Id"]
$stepName = $OctopusParameters["Octopus.Step.Name"]

$regionName = $OctopusParameters["AWS.Lambda.Region"]

if ($null -ne $OctopusParameters["Octopus.Action.Package[AWS.Lambda.Package].Image"]) {
    $imageUri = $OctopusParameters["Octopus.Action.Package[AWS.Lambda.Package].Image"]
}

if ([string]::IsNullOrWhiteSpace($functionName)) {
    Write-Error "The parameter Function Name is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($functionRole)) {
    Write-Error "The parameter Role is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($functionReleaseNumber) -eq $false) {
    $deployVersionTag = "Octopus-Release=$functionReleaseNumber"
}
else {
    $deployVersionTag = "Octopus-Runbook-Run=$functionRunbookRun"
}

Write-Host "Function Name: $functionName"
Write-Host "Function Role: $functionRole"
Write-Host "Function Memory Size: $functionMemorySize"
Write-Host "Function Description: $functionDescription"
Write-Host "Function Subnet Ids: $functionVPCSubnetId"
Write-Host "Function Security Group Ids: $functionVPCSecurityGroupId"
Write-Host "Function Timeout: $functionTimeout"
Write-Host "Function Tags: $functionTags"
Write-Host "Function File System Config: $functionFileSystemConfig"
Write-Host "Function Dead Letter Config: $functionDeadLetterConfig"
Write-Host "Function Tracing Config: $functionTracingConfig"
Write-Host "Function Publish: $functionPublishOption"
Write-Host "Function Image URI: $imageUri"
Write-Host "Function Environment Variables: $functionEnvironmentVariables"
Write-Host "Function Environment Variables Key: $functionEnvironmentVariablesKey"

if (![string]::IsNullOrWhitespace($OctopusParameters["AWS.Lambda.Image.Entrypoint"]))
{
  Write-Host "Image Entrypoint override: $($OctopusParameters["AWS.Lambda.Image.Entrypoint"])"
}

if (![string]::IsNullOrWhitespace($OctopusParameters["AWS.Lambda.Image.Command"]))
{
  Write-Host "Image Command override: $($OctopusParameters["AWS.Lambda.Image.Command"])"
}


Write-Host "Attempting to find the function $functionName in the region $regionName"
$hasExistingFunction = $true

try {
    $existingFunction = aws lambda get-function --function-name "$functionName" 2> $null
    
    Write-Host "The exit code from the lookup was $LASTEXITCODE"
    if ($LASTEXITCODE -eq 255 -or $LASTEXITCODE -eq 254) {
        $hasExistingFunction = $false
    }   
    
    $existingFunction = $existingFunction | ConvertFrom-Json
}
catch {
    Write-Host "The function was not found"
    $hasExistingFunction = $false
}

Write-Host "Existing functions: $hasExistingFunction"
Write-Host $existingFunction

# Init argument variable
$lambdaArguments = @("lambda")
$waitArguments = @("lambda", "wait")

if ($hasExistingFunction -eq $false) {
    Write-Highlight "Creating $functionName in $regionName"

    $waitArguments += @("function-active-v2")

    $lambdaArguments += @("create-function", "--role", $functionRole, "--memory-size", $functionMemorySize)

    if ($null -ne $imageUri) {
        Write-Host "Deploying Lambda container ..."
        $lambdaArguments += @("--code", "ImageUri=$imageUri", "--package-type", "Image")
      
        if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Entrypoint']) -or ![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Command'])) {
            $lambdaArguments += "--image-config"
        
            if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Entrypoint'])) {
                $lambdaArguments += "EntryPoint=$($OctopusParameters['AWS.Lambda.Image.Entrypoint'])"
            }

            if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Command'])) {
                $lambdaArguments += "Command=$($OctopusParameters['AWS.Lambda.Image.Command'])"
            }
        }
    }
}
else {
    Write-Highlight "Updating the $functionName code"

    $waitArguments += @("function-updated")
    $lambdaArguments += "update-function-code"

    if ($null -ne $imageUri) {
        Write-Host "Deploying Lambda container ..."
        $lambdaArguments += @("--image-uri", $imageUri)
    }
}

$waitArguments += @("--function-name", "$functionName")

$lambdaArguments += @("--function-name", "$functionName")

# Wait for function to be done creating
Write-Host "Running aws $lambdaArguments ..."
$functionInformation = (aws $lambdaArguments)
(aws $waitArguments)


if ($hasExistingFunction -eq $true) {
    # update configuration
    $lambdaArguments = @("lambda", "update-function-configuration", "--function-name", "$functionName", "--role", $functionRole, "--memory-size", $functionMemorySize)
       
    if ($null -ne $imageUri) {
        Write-Highlight "Updating the $functionName image configuration"
        if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Entrypoint']) -or ![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Command'])) {
            $lambdaArguments += "--image-config"
        
            if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Entrypoint'])) {
                $lambdaArguments += "EntryPoint=$($OctopusParameters['AWS.Lambda.Image.Entrypoint'])"
            }

            if (![string]::IsNullOrWhitespace($OctopusParameters['AWS.Lambda.Image.Command'])) {
                $lambdaArguments += "Command=$($OctopusParameters['AWS.Lambda.Image.Command'])"
            }
        }
    }
    
    $functionInformation = (aws $lambdaArguments)
    Write-Highlight "Waiting for configuration update to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

$functionInformation = $functionInformation | ConvertFrom-JSON
$functionArn = $functionInformation.FunctionArn

Write-Host "Function ARN: $functionArn"

if ([string]::IsNullOrWhiteSpace($functionEnvironmentVariables) -eq $false) {
    Write-Highlight "Environment variables specified, updating environment variables configuration for $functionName"
    $environmentVariables = "Variables={$functionEnvironmentVariables}"
    
    if ([string]::IsNullOrWhiteSpace($functionEnvironmentVariablesKey) -eq $true) {
        $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --environment "$environmentVariables"
    }
    else {
        $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --environment "$environmentVariables" --kms-key-arn "$functionEnvironmentVariablesKey"
    }
    
    Write-Highlight "Waiting for environment variable update to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionTimeout) -eq $false) {
    Write-Highlight "Timeout specified, updating timeout configuration for $functionName"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --timeout "$functionTimeout"
    
    Write-Highlight "Waiting for timeout upate to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionTags) -eq $false) {
    Write-Highlight "Tags specified, updating tags configuration for $functionName"
    $updatedConfig = aws lambda tag-resource --resource "$functionArn" --tags "$functionTags"
}

if ([string]::IsNullOrWhiteSpace($deployVersionTag) -eq $false) {
    Write-Highlight "Deploy version tag found with value of $deployVersionTag, updating tags configuration for $functionName"
    aws lambda untag-resource --resource "$functionArn" --tag-keys "Octopus-Release" "Octopus-Runbook-Run"
    $updatedConfig = aws lambda tag-resource --resource "$functionArn" --tags "$deployVersionTag"
}

if ([string]::IsNullOrWhiteSpace($functionVPCSubnetId) -eq $false -and [string]::IsNullOrWhiteSpace($functionVPCSecurityGroupId) -eq $false) {
    Write-Highlight "VPC subnets and security group specified, updating vpc configuration for $functionName"
    $vpcConfig = "SubnetIds=$functionVPCSubnetId,SecurityGroupIds=$functionVPCSecurityGroupId"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --vpc-config "$vpcConfig"
    
    Write-Highlight "Waiting for vpc configuration to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionDescription) -eq $false) {
    Write-Highlight "Description specified, updating description configuration for $functionName"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --description "$functionDescription"
    
    Write-Highlight "Waiting for description configuration ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionFileSystemConfig) -eq $false) {
    Write-Highlight "File System Config specified, updating file system configuration for $functionName"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --file-system-configs "$functionFileSystemConfig"	
    
    Write-Highlight "Wating for file system configuration update to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionDeadLetterConfig) -eq $false) {
    Write-Highlight "Dead Letter specified, updating dead letter configuration for $functionName"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --dead-letter-config "$functionDeadLetterConfig"	
    
    Write-Highlight "Waitng for Dead Letter configuration update to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

if ([string]::IsNullOrWhiteSpace($functionTracingConfig) -eq $false) {
    Write-Highlight "Tracing config specified, updating tracing configuration for $functionName"
    $updatedConfig = aws lambda update-function-configuration --function-name "$functionArn" --tracing-config "$functionTracingConfig"	
    
    Write-Highlight "Waiting for tracing configuration to complete ..."
    aws lambda wait function-updated --function-name "$functionName"
}

Write-Host $updatedConfig | ConvertFrom-JSON

if ($functionPublishOption -eq "Yes") {
    Write-Highlight "Publishing the function with the description $functionVersionNumber to create a snapshot of the current code and configuration of this function in AWS."
    $publishedVersion = aws lambda publish-version --function-name "$functionArn" --description "$functionVersionNumber"
    
    $publishedVersion = $publishedVersion | ConvertFrom-JSON
    
    Write-Highlight "Setting the output variable 'Octopus.Action[$($stepName)].Output.PublishedVersion' to $($publishedVersion.Version)"
    Set-OctopusVariable -name "PublishedVersion" -value "$($publishedVersion.Version)"    
}

Write-Highlight "Setting the output variable 'Octopus.Action[$($stepName)].Output.LambdaArn' to $functionArn"
Set-OctopusVariable -name "LambdaArn" -value "$functionArn"

Write-Highlight "AWS Lambda $functionName successfully deployed."