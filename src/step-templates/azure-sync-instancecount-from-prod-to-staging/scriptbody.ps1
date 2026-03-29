# Current Cloud Service name 
$ServiceName =$octopusparameters["Octopus.Action.Azure.CloudServiceName"]

$deployment = Get-AzureDeployment -slot $sourceslot -serviceName $serviceName
# Obtain the instance count and role name.
$SourceInstanceCount =$deployment.RolesConfiguration.values.InstanceCount
$rolenameService = $deployment.RolesConfiguration.values.Name
#Set the Current deployment slot instance count to match production count
Set-AzureRole -ServiceName $serviceName -Slot $octopusparameters["Octopus.Action.Azure.Slot"] -RoleName $rolenameService -Count $SourceInstanceCount 