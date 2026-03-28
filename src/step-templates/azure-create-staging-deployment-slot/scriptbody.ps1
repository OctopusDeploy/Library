###############################################
# Create Azure RM Staging Deployment Slot
###############################################
##Step1: Get Variables
$ResourceGroupName             = $OctopusParameters["ResourceGroupName"] 
$AppName                       = $OctopusParameters["AppName"] 
$stagingSlotName               = $OctopusParameters["SlotName"]
$AppServicePlanName            = $OctopusParameters["AppServicePlanName"] 
###############################################
###############################################
Function Add-DeploymentSlotFunctionaility
{
    [cmdletbinding()]
    param
    (   
        [string]$ResourceGroupName,
        [string]$AppName,
        [string]$AppServicePlanName
    )
    try 
    {
        write-output "Will make sure the service plan can support deployment slots"
        $servicePlan = Get-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName
    
        if(($servicePlan.Sku.Tier.ToLower() -eq "free" ) -or ($servicePlan.Sku.Tier.ToLower() -eq "shared" ) -or ($servicePlan.Sku.Tier.ToLower() -eq "basic" ))
        {
            Write-Warning "Service plan does not currently support deployment slots, will now scale to standard tier"
            $planUpdate = Set-AzureRmAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Tier "Standard"
            Write-Output "Plan updated"
            $planUpdate | Out-String | Write-Verbose
            write-output "Plan Tier now set to:"
            $planUpdate.Sku | Out-String | Write-Output
        }
        else 
        {
            Write-Output "Service plan already supports deployment slots"    
        }       
    }
    catch 
    {
        throw "Error adding Deployment Slot functionailty. $_"    
    }
}

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

    if([string]::IsNullOrEmpty($AppServicePlanName))
    {
        write-error "AppServicePlanName variable is not set"
    }
    Write-Verbose "Variables in use are:"
    write-verbose "ResourceGroupName:$ResourceGroupName"
    write-verbose "AppName:$AppName"
    write-verbose "stagingSlotName:$stagingSlotName"
    write-verbose "AppServicePlanName:$AppServicePlanName"
}

$ErrorActionPreference = "Stop"

try 
{
    Invoke-RequiredVariablesCheck
    Add-DeploymentSlotFunctionaility -ResourceGroupName $ResourceGroupName -AppName $AppName -AppServicePlanName $AppServicePlanName
    Write-output "Preparing Deployment Staging slot"
    $deploymentSlot = Get-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -Slot $stagingSlotName -ErrorAction SilentlyContinue
    if($deploymentSlot.Id -eq $null)
    {
        Write-output "No current deployment slot created, will create one now"
        New-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -Slot $stagingSlotName
    }
    else 
    {   
        Write-Verbose "Current slot exists, will remove to speed up deployment"
        Remove-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -Slot $stagingSlotName -Force
        Write-Verbose "Slot removed"
        New-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $AppName -Slot $stagingSlotName   
    }
    Write-Output "Deployment slot $stagingSlotName created"
}
catch 
{
    Write-Error "Error in Create Azure RM Staging Deployment Slot step. $_"    
}