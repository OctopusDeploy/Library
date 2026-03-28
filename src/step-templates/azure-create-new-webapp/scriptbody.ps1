###############################################
##Step 1: Get Variables
$ResourceGroupName             = $OctopusParameters["ResourceGroupName"] 
$DeploymentLocation            = $OctopusParameters["Location"] 
$AppServicePlanName            = $OctopusParameters["AppServicePlanName"] 
$AppServicePlanTier            = $OctopusParameters["AppServicePlanTier"]
$WebAppName                    = $OctopusParameters["WebAppName"]
$TimeStamp                          = Get-Date -Format ddMMyyyy_hhmmss
$PublishProfilePath                 = Join-Path -Path $ENV:Temp -ChildPath "publishprofile$TimeStamp.xml"
$AppServiceUse32BitWorkerProcess= $OctopusParameters["AppServiceUse32BitWorkerProcess"] 
###############################################

###############################################
##Step 2: Check and Create Service Plan
try{
  $ServicePlan= Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName  -ErrorAction SilentlyContinue 
  if ($null -eq $ServicePlan)
  {
    Write-Output "Creating Service Plan"
    $ServicePlan=New-AzureRmAppServicePlan -Name $AppServicePlanName -Location $Location -ResourceGroupName $ResourceGroupName -Tier $AppServicePlanTier
  }
  else{
      Write-Output "Service Plan already set up"
  }
  $WebApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -ErrorAction SilentlyContinue
  if($null -eq $WebApp)
  {
      Write-Output "Creating WebApp"
      $webApp = New-AzureRmWebApp -Name $WebAppName -AppServicePlan $AppServicePlanName -ResourceGroupName $ResourceGroupName -Location $DeploymentLocation
  }
  else {
      Write-Output "WebApp already created"
  }
  
  Write-Output "setting app to use $AppServiceUse32BitWorkerProcess" 
  Set-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -Use32BitWorkerProcess ([bool]$AppServiceUse32BitWorkerProcess)
  $null = Get-AzureRmWebAppPublishingProfile -OutputFile $PublishProfilePath -ResourceGroupName $ResourceGroupName -Name $WebAppName -Format WebDeploy -Verbose
  
  Write-output "profile: $(get-content  $PublishProfilePath)"
  if (!(Test-Path -Path $PublishProfilePath)){
    throw [System.IO.FileNotFoundException] "$PublishProfilePath not found."
  }

    get-childitem $psscriptroot
}
catch{
  Write-Output "Cannot add serviceplan/webapp : $AzureAppServicePlanName / $AzureWebAppName"
  Write-Output $_

}
