Function Test-CommandExists
{
	Param ($command)
	$oldPreference = $ErrorActionPreference
	$ErrorActionPreference = 'stop'
	Try {
    	if(Get-Command $command){
        	return $true
        }
    } Catch {
    	Write-Host "$command does not exist"
        return $false
    } Finally {
    	$ErrorActionPreference=$oldPreference
   	}
}

If ([string]::IsNullOrWhiteSpace($OctopusParameters["Pulumi.AccessToken"])) {
	Fail-Step "Parameter Pulumi.AccessToken cannot be empty."
}

$env:PULUMI_ACCESS_TOKEN=$OctopusParameters["Pulumi.AccessToken"]

If ((Test-CommandExists pulumi) -eq $false) {
	(new-object net.webclient).DownloadFile("https://get.pulumi.com/install.ps1","local.ps1")
    ./local.ps1
	$pulumiInstallRoot=(Join-Path $env:UserProfile ".pulumi")
	$binRoot=(Join-Path $pulumiInstallRoot "bin")
	$env:Path+=";$binRoot"
}

# Check for AWS access key credentials and set those in the env.
If (![string]::IsNullOrWhiteSpace($OctopusParameters["AWS.AccessKey"])) {
	$env:AWS_ACCESS_KEY_ID=$OctopusParameters["AWS.AccessKey"]
}

If (![string]::IsNullOrWhiteSpace($OctopusParameters["AWS.SecretKey"])) {
	$env:AWS_SECRET_ACCESS_KEY=$OctopusParameters["AWS.SecretKey"]
}

# Check for Azure SP/personal account credentials and set those in the env.
If (![string]::IsNullOrWhiteSpace($OctopusParameters["Azure.Client"])) {
	$env:ARM_CLIENT_ID=$OctopusParameters["Azure.Client"]
}

If (![string]::IsNullOrWhiteSpace($OctopusParameters["Azure.Password"])) {
	$env:ARM_CLIENT_SECRET=$OctopusParameters["Azure.Password"]
}

If (![string]::IsNullOrWhiteSpace($OctopusParameters["Azure.TenantId"])) {
	$env:ARM_TENANT_ID=$OctopusParameters["Azure.TenantId"]
}

If (![string]::IsNullOrWhiteSpace($OctopusParameters["Azure.SubscriptionNumber"])) {
	$env:ARM_SUBSCRIPTION_ID=$OctopusParameters["Azure.SubscriptionNumber"]
}

Write-Host "Logging in to Pulumi using access token"
pulumi login

$cwd=$OctopusParameters["Pulumi.WorkingDirectory"]
If (![string]::IsNullOrWhiteSpace($cwd)) {
	cd $cwd
}

$stackName=$OctopusParameters["Pulumi.StackName"]
Write-Host "Selecting stack $stackName"
Try {
	pulumi stack select $stackName
}
Catch {
	$createStackIfNotExists = $OctopusParameters["Pulumi.CreateStack"]
	If ($createStackIfNotExists -eq "True") {
    	pulumi stack init $stackName
    } Else {
    	Fail-Step "Stack $stackName does not exist."
    }
}

$restoreDeps=$OctopusParameters["Pulumi.RestoreDeps"]
If ($restoreDeps -eq "True") {
	Write-Host "Restoring dependencies..."
    $restoreDepsCmd = $OctopusParameters["Pulumi.RestoreCmd"]
    Invoke-Expression $restoreDepsCmd
}

$pulCmd=$OctopusParameters["Pulumi.Command"]
$pulArgs=$OctopusParameters["Pulumi.Args"]
If (![string]::IsNullOrWhiteSpace($pulArgs)) {
	pulumi $pulCmd $pulArgs
}
Else {
	pulumi $pulCmd
}
