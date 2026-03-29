# Check for the PowerShell cmdlets (from AWS - Create Cloud Formation Stack Octopus Step).
try{ 
    Import-Module AWSPowerShell -ErrorAction Stop
}catch{
    
    $modulePath = "C:\Program Files (x86)\AWS Tools\PowerShell\AWSPowerShell\AWSPowerShell.psd1"
    Write-Output "Unable to find the AWS module checking $modulePath" 
    
    try{
        Import-Module $modulePath        
    }
    catch{
        throw "AWS PowerShell not found! Please make sure to install them from https://aws.amazon.com/powershell/" 
    }
}

function Get-EnvironmentVariables () {
    $resultEV = @{}
    $environmentVariableConst = 'env.'

    $envVariables = $OctopusParameters.Keys | ? {$_ -like $environmentVariableConst + '*' }
    
    foreach($item in $envVariables)
    {
        $key = $item.Replace($environmentVariableConst, '')
        $value = $OctopusParameters[$item]

        $resultEV.Add($key, $value)
    }
    
    return $resultEV
}

# Get the parameters.
$functionName = $OctopusParameters['FunctionName']
$functionZip = $OctopusParameters['FunctionZip']
$handler = $OctopusParameters['Handler']
$runtime = $OctopusParameters['Runtime']
$role = $OctopusParameters['Role']
$description = $OctopusParameters['Description']
$memorySize = $OctopusParameters['MemorySize']
$timeout = $OctopusParameters['Timeout']
$awsRegion = $OctopusParameters['AWSRegion']
$awsSecretAccessKey = $OctopusParameters['AWSSecretAccessKey']
$awsAccessKey = $OctopusParameters['AWSAccessKey']
$AWSCL_VpcConfig_SubnetId = $OctopusParameters['AWSCL_VpcConfig_SubnetId']
$vpcSubnetIds = if($AWSCL_VpcConfig_SubnetId) { $AWSCL_VpcConfig_SubnetId.Split(',') }
$AWSCL_VpcConfig_SecurityGroupId = $OctopusParameters['AWSCL_VpcConfig_SecurityGroupId']
if($AWSCL_VpcConfig_SecurityGroupId) { $vpcSecurityGroupIds = $AWSCL_VpcConfig_SecurityGroupId.Split(',') }

# Check the parameters.
if (-NOT $awsSecretAccessKey) { throw "You must enter a value for 'AWS Access Key'." }
if (-NOT $awsAccessKey) { throw "You must enter a value for 'AWS Secret Access Key'." }
if (-NOT $awsRegion) { throw "You must enter a value for 'AWS Region'." }
if (-NOT $functionName) { throw "You must enter a value for 'Function Name'." }
if (-NOT $functionZip) { throw "You must enter a value for 'Function Zip'." }
if (-NOT $handler) { throw "You must enter a value for 'Handler'." }
if (-NOT $runtime) { throw "You must enter a value for 'Runtime'." }
if (-NOT $role) { throw "You must enter a value for 'Role'." }
if (-NOT $memorySize) { throw "You must enter a value for 'Memory Size'." }
if (-NOT $timeout) { throw "You must enter a value for 'Timeout'." }

Write-Output "--------------------------------------------------"
Write-Output "AWS Region: $awsRegion"
Write-Output "AWS Lambda Function Name: $functionName"
Write-Output "AWS Lambda Handler: $handler"
Write-Output "AWS Lambda Runtime: $runtime"
Write-Output "AWS Lambda Memory Size: $memorySize"
Write-Output "AWS Lambda Timeout: $timeout"
Write-Output "AWS Lambda Role: $role"
Write-Output "--------------------------------------------------"

# Set up the credentials and the dependencies.
Set-DefaultAWSRegion -Region $awsRegion
$credential = New-AWSCredentials -AccessKey $awsAccessKey -SecretKey $awsSecretAccessKey

$awsEnvironmentVariables = Get-EnvironmentVariables

# Check if the function exists, with a try catch
try {
    Get-LMFunction -Credential $credential -FunctionName $functionName -Region $awsRegion
    
    Write-Host 'Updating Lambda function code.'

    # Update the function.
    Update-LMFunctionCode -Credential $credential -Region $awsRegion -FunctionName $functionName -ZipFilename  $functionZip
    
    Write-Host 'Updating Lambda function configuration.'

    Update-LMFunctionConfiguration -Credential $credential -Region $awsRegion -FunctionName $functionName -Description $description -Handler $handler -MemorySize $memorySize -Role $role -Runtime $runtime -Timeout $timeout -Environment_Variable $awsEnvironmentVariables -VpcConfig_SecurityGroupId $vpcSecurityGroupIds -VpcConfig_SubnetId $vpcSubnetIds
    
    # Feedback
    Write-Output "--------------------------------------------------"
    Write-Output "AWS Lambda Function updated."
    Write-Output "--------------------------------------------------"
}
catch {
    # Create the function.
    Publish-LMFunction -Credential $credential -Region $awsRegion -FunctionName $functionName -FunctionZip $functionZip -Handler $handler -Runtime $runtime -Role $role -Description $description -MemorySize $memorySize -Timeout $timeout -Environment_Variable $awsEnvironmentVariables -VpcConfig_SecurityGroupId $vpcSecurityGroupIds -VpcConfig_SubnetId $vpcSubnetIds

    # Feedback
    Write-Output "--------------------------------------------------"
    Write-Output "AWS Lambda Function created."
    Write-Output "--------------------------------------------------"
}
