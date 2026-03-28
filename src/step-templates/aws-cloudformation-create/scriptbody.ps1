#http://docs.aws.amazon.com/powershell/latest/reference/items/New-CFNStack.html

#Check for the PowerShell cmdlets
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

function Confirm-CFNStackDeleted($credential, $stackName){
   do{
        $stack = $null
        try {
            $stack = Get-CFNStack -StackName $CloudFormationStackName -Credential $credential -Region $AWSRegion       
        }
        catch{}
        
        if($stack -ne $null){

			$stack | ForEach-Object {
				$progress = $_.StackStatus.ToString()
				$name = $_.StackName.ToString()

				Write-Host "Waiting for Cloud Formation Script to deleted. Stack Name: $name Operation status: $progress" 
         
				if($progress -ne "DELETE_COMPLETE" -and $progress -ne "DELETE_IN_PROGRESS"){                        
					$stack
					throw "Something went wrong deleting the Cloud Formation Template" 
				} 	 		
			} 
			 
            Start-Sleep -s 15
        }

    }until ($stack -eq $null)
}

function Confirm-CFNStackCompleted($credential, $stackName, $region){

    $awsValidStatusList = @()
    $awsValidStatusList += "CREATE_COMPLETE"
    $awsValidStatusList += "CREATE_IN_PROGRESS" 
    
    $awsFailedStatusList = @()
    $awsFailedStatusList += "CREATE_FAILED"
    $awsFailedStatusList += "UPDATE_FAILED"
    $awsFailedStatusList += "DELETE_SKIPPED"
    $awsFailedStatusList += "CREATE_FAILED"
    $awsFailedStatusList += "CREATE_FAILED"

	#http://docs.aws.amazon.com/powershell/latest/reference/Index.html
    #CREATE_COMPLETE | CREATE_FAILED | CREATE_IN_PROGRESS | DELETE_COMPLETE | DELETE_FAILED | DELETE_IN_PROGRESS | DELETE_SKIPPED | UPDATE_COMPLETE | UPDATE_FAILED | UPDATE_IN_PROGRESS.
	 
    do{
        $stack = Get-CFNStack -StackName $stackName -Credential $credential -Region $region  
		$complete = $false

		#Depending on the template sometimes there are multiple status per CFN template

		$stack | ForEach-Object {
			$progress = $_.StackStatus.ToString()
			$name = $_.StackName.ToString()

			Write-Host "Waiting for Cloud Formation Script to complete. Stack Name: $name Operation status: $progress" 
         
			if($progress -ne "CREATE_COMPLETE" -and $progress -ne "CREATE_IN_PROGRESS"){                        
				$stack
				throw "Something went wrong creating the Cloud Formation Template" 
			} 	 		
		}

		$inProgress = $stack | Where-Object { $_.StackStatus.ToString() -eq "CREATE_IN_PROGRESS" }
		
		if($inProgress.Count -eq 0){
			$complete = $true
		}
		 
        Start-Sleep -s 15

    }until ($complete -eq $true)
}

# Check the parameters.
if (-NOT $AWSSecretAccessKey) { throw "You must enter a value for 'AWS Access Key'." }
if (-NOT $AWSAccessKey) { throw "You must enter a value for 'AWS Secret Access Key'." }
if (-NOT $AWSRegion) { throw "You must enter a value for 'AWS Region'." }
if (-NOT $CloudFormationStackName) { throw "You must enter a value for 'AWS Cloud Formation Stack Name'." }  


#Reformat the CloudFormation parameters
$paramObject = ConvertFrom-Json $CloudFormationParameters
$cloudFormationParams = @()

$paramObject.psobject.properties | ForEach-Object { 
    $keyPair = New-Object -Type Amazon.CloudFormation.Model.Parameter
    $keyPair.ParameterKey = $_.Name
    $keyPair.ParameterValue = $_.Value

    $cloudFormationParams += $keyPair
} 

Write-Output "--------------------------------------------------"
Write-Output "AWS Region: $AWSRegion"
Write-Output "AWS Cloud Formation Stack Name: $CloudFormationStackName"
Write-Output "Use S3 for AWS Cloud Formation Script?: $UseS3ForCloudFormationTemplate"
Write-Output "Use S3 for AWS Cloud Formation Stack Policy?: $UseS3ForStackPolicy"
Write-Output "AWS Cloud Formation Script Url: $CloudFormationTemplateURL"
Write-Output "AWS Cloud Formation Stack Policy Url: $CloudFormationStackPolicyURL"
Write-Output "AWS Cloud Formation Parameters:"
Write-Output $cloudFormationParams
Write-Output "--------------------------------------------------"

#Set up the credentials and the dependencies
Set-DefaultAWSRegion -Region $AWSRegion
$credential = New-AWSCredentials -AccessKey $AWSAccessKey -SecretKey $AWSSecretAccessKey  

#Check to see if the stack exists
try{
    $stack = Get-CFNStack -StackName $CloudFormationStackName -Credential $credential -Region $AWSRegion    
}
catch{} #Do nothing as this will throw if the stack does not exist

if($stack -ne $null){
    if($DeleteExistingStack -eq $false) {
        Write-Output "Stack with name $CloudFormationStackName already exists. If you wish to automatically delete existing stacks, set 'Delete Existing Stack' to True."
        exit -1
    }
    Write-Output "Stack found, removing the existing Cloud Formation Stack"           
    
    Remove-CFNStack -Credential $credential -StackName $CloudFormationStackName -Region $AWSRegion -Force
    Confirm-CFNStackDeleted -credential $credential -stackName $CloudFormationStackName
}

if($UseS3ForCloudFormationTemplate -eq $true){   

    if (-NOT $CloudFormationTemplateURL) { throw "You must enter a value for 'AWS Cloud Formation Template'." } 

    if($UseS3ForStackPolicy -eq $true){
        Write-Output "Using Cloud Formation Stack Policy from $CloudFormationStackPolicyURL"
        New-CFNStack -Credential $credential -OnFailure $CloudFormationOnFailure -TemplateUrl $CloudFormationTemplateURL -StackName $CloudFormationStackName -Region $AWSRegion -Parameter $cloudFormationParams -Capability $CloudFormationCapability -StackPolicyURL $CloudFormationStackPolicyURL
    }
    else {
        New-CFNStack -Credential $credential -OnFailure $CloudFormationOnFailure -TemplateUrl $CloudFormationTemplateURL -StackName $CloudFormationStackName -Region $AWSRegion -Parameter $cloudFormationParams -Capability $CloudFormationCapability            
    }

    Confirm-CFNStackCompleted -credential $credential -stackName $CloudFormationStackName -region $AWSRegion
}
else{
    
    Write-Output "Using Cloud Formation script from Template"

    $validTemplate = Test-CFNTemplate -TemplateBody $CloudFormationTemplate -Region $AWSRegion  -Credential $credential
    $statusCode =  $validTemplate.HttpStatusCode.ToString()

    Write-Output "Validation Response: $statusCode"

    if($validTemplate.HttpStatusCode){

        if($UseS3ForStackPolicy -eq $true){
            Write-Output "Using Cloud Formation Stack Policy from $CloudFormationStackPolicyURL"
            New-CFNStack -Credential $credential -OnFailure $CloudFormationOnFailure -TemplateBody $CloudFormationTemplate -StackName $CloudFormationStackName -Region $AWSRegion -Parameter $cloudFormationParams -Capability $CloudFormationCapability -StackPolicyURL $CloudFormationStackPolicyURL
        }
        else {
            New-CFNStack -Credential $credential -OnFailure $CloudFormationOnFailure -TemplateBody $CloudFormationTemplate -StackName $CloudFormationStackName -Region $AWSRegion -Parameter $cloudFormationParams -Capability $CloudFormationCapability
        }

        Confirm-CFNStackCompleted -credential $credential -stackName $CloudFormationStackName -region $AWSRegion
    }
    else{
        throw "AWS Cloud Formation template is not valid"
    }         
}

$stack = Get-CFNStack -StackName $CloudFormationStackName -Credential $credential -Region $AWSRegion   

Set-OctopusVariable -name "AWSCloudFormationStack" -value $stack
