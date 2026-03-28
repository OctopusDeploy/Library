###############################################
# Switch Azure RM Staging Deployment Slot
###############################################
###############################################
##Step1: Get Variables
$ResourceGroupName             = $OctopusParameters["ResourceGroupName"] 
$AppName                       = $OctopusParameters["AppName"] 
$StagingSlotName               = $OctopusParameters["SlotName"]
$SmokeTestResponseCode         = $OctopusParameters["SmokeTestResponseCode"]
$smokeTestTimeoutSecs          = $OctopusParameters["smokeTestTimeoutSecs"]
###############################################
###############################################
$ErrorActionPreference = "Stop"

Function Invoke-RequiredVariablesCheck
{
    if([string]::IsNullOrEmpty($ResourceGroupName))
    {
        Write-Error "ResourceGroupName variable is not set"
    }

    if([string]::IsNullOrEmpty($AppName))
    {
        write-error "AppName variable is not set"
    }

    if([string]::IsNullOrEmpty($stagingSlotName))
    {
        write-error "stagingSlotName variable is not set"
    }

    if([string]::IsNullOrEmpty($smokeTestTimeoutSecs))
    {
        Write-Output "Smoke test timeout not set, will use default of 180 seconds"
        $smokeTestTimeoutSecs = 180
    }

    if([string]::IsNullOrEmpty($SmokeTestResponseCode))
    {
        Write-Output "Smoke test respose code not specfied will detail to 200"
        $SmokeTestResponseCode = "200"
    }

    Write-Verbose "Variables in use are:"
    write-verbose "ResourceGroupName:$ResourceGroupName"
    write-verbose "AppName:$AppName"
    write-verbose "stagingSlotName:$stagingSlotName"
    Write-Verbose "smokeTestTimeoutSecs: $smokeTestTimeoutSecs"
    Write-Verbose "SmokeTestResponseCode: $SmokeTestResponseCode"
}

Function Invoke-SlotWarmup
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory=$true)]
        [string]$httpEndpoint,
        [parameter(Mandatory=$true)]
        [int32]$timeout
    )
    try 
    {
        $response = (Invoke-WebRequest -UseBasicParsing -Uri $httpEndpoint -TimeoutSec $timeout).statusCode
    }
    catch 
    {
        $response = $_.Exception.Response.StatusCode.Value__
    }
    return $response
}

try 
{
    Invoke-RequiredVariablesCheck
    Write-Output "Will attempt to warm up staging slot"
    $slotDetails = Get-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -Slot $StagingSlotName
    
    $hostname = $slotDetails.EnabledHostNames | select-object -First 1

    Write-Output "Performing default smoke test to warm up deployment slot"
    
    $returnStatusCode = Invoke-SlotWarmup -httpEndpoint "https://$hostname" -timeout $smokeTestTimeoutSecs

    if($returnStatusCode -ne $SmokeTestResponseCode)
    {
        Write-Error "Response code to https://$hostname was $returnStatusCode and did not match the expected response code of $SmokeTestResponseCode. Deployment canceled"
    }
    else 
    {
        Write-Output "Staging slot (https://$hostname) warmed up and responding ok"
    }

    Write-Output "Will now switch staging slot to production"
    Switch-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -SourceSlotName $StagingSlotName -DestinationSlotName "Production"
    Write-Output "Deployment slot switch complete"
}
catch 
{
    Write-Error "Error in Switch Azure RM Staging Deployment Slot Script. $_"    
}