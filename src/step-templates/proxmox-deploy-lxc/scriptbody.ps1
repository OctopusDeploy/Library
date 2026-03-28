# Proxmox Connection Variables
$ProxmoxHost = $OctopusParameters["Proxmox.Host"];
$ProxmoxPort = [int]$OctopusParameters["Proxmox.Port"];
$ProxmoxUser = $OctopusParameters["Proxmox.User"];

$ProxmoxNode = $OctopusParameters["Proxmox.Node"];

$ProxmoxTokenID = $OctopusParameters["Proxmox.TokenID"];
$ProxmoxToken = $OctopusParameters["Proxmox.Token"];

# LXC Variables
$LXC_VMID = [int]$OctopusParameters["Proxmox.LXC.VMID"];
$LXC_Hostname = $OctopusParameters["Proxmox.LXC.Hostname"];
$LXC_OSTemplate = $OctopusParameters["Proxmox.LXC.OSTemplate"];
$LXC_Storage = $OctopusParameters["Proxmox.LXC.Storage"];
$LXC_CPU = [int]$OctopusParameters["Proxmox.LXC.Cores"];
$LXC_Memory = [int]$OctopusParameters["Proxmox.LXC.Memory"];
$LXC_RootSize = [int]$OctopusParameters["Proxmox.LXC.RootSize"];
$LXC_Networks = $OctopusParameters["Proxmox.LXC.Network"];
$LXC_Password = $OctopusParameters["Proxmox.LXC.Password"];

$BaseURL = "https://$($ProxmoxHost):$($ProxmoxPort)/api2/json"

$header = @{
	"Authorization" = "PVEAPIToken=$($ProxmoxUser)!$($ProxmoxTokenID)=$($ProxmoxToken)"
}


Write-Host "Testing Connection To Proxmox Server/Cluster ..."

try{
	Invoke-RestMethod -Method GET -uri "$($BaseURL)" -Headers $header | out-null
}catch{
	throw "Couldn't Connect to the Proxmox Server/Cluster"
}

Write-Host "Successfully Connected To Proxmox Server/Cluster"

$LXC_Start = 0
try {
  $Start = [System.Convert]::ToBoolean($OctopusParameters["Proxmox.LXC.StartOnCreate"])
  
  if($Start -eq $True){
  	$LXC_Start = 1
  }
  
} catch {}

$LXC_Force = 0
try {
  $Force = [System.Convert]::ToBoolean($OctopusParameters["Proxmox.LXC.Force"])
  
  if($Force -eq $True){
  	$LXC_Force = 1
  }
  
} catch {}

if($LXC_CPU -lt 1){
	$LXC_CPU=1;
}

if($LXC_Memory -lt 16){
	$LXC_Memory = 16;
}

if($LXC_RootSize -lt 1){
	$LXC_RootSize = 1;
}

if($LXC_Hostname -eq $null -or $LXC_Hostname -eq ""){
	throw "LXC Hostname must be provided!"
}

if($LXC_OSTemplate -eq $null -or $LXC_OSTemplate -eq ""){
	throw "LXC OS Template must be provided!"
}

if($LXC_Storage -eq $null -or $LXC_Storage -eq ""){
	throw "LXC Storage must be provided!"
}

if($LXC_Networks -eq $null){
	throw "You must provide at least one network property"
}

if($LXC_Password -eq $null -or $LXC_Password -eq ""){
	throw "LXC Password must be provided!"
}

if($LXC_VMID -eq "-1"){
	$LXC_VMID=(Invoke-RestMethod -Method GET -uri "$($BaseURL)/cluster/nextid" -headers $header).data
    Write-Host "Found next vm id: $($LXC_VMID)"
}

if($LXC_VMID -lt 1){
	throw "The LXC VMID was not valid ($LXC_VMID), Set this to -1 to automatically find the next id"
}

$LXCData = @{
	"vmid" = $LXC_VMID
    "hostname" = $LXC_Hostname
    "ostemplate" = $LXC_OSTemplate
    "rootfs" = "volume=$($LXC_Storage):$($LXC_RootSize)"
    "cores" = $LXC_CPU
    "memory" = $LXC_Memory
    "storage" = $LXC_Storage
    "password" = $LXC_Password
    "start" = $LXC_Start
    "force" = $LXC_Force
}

$NetworkIndex = 0;

$Networks = $LXC_Networks.replace("\n", "`n").split("`n")

if($Networks.Count -lt 1){
	throw "You must provide at least one network property"
}

foreach ($network in $Networks){
    $LXCData["net$($NetworkIndex)"] = $network;
    $NetworkIndex++;
}

$existingLXC = $null;

try{
    $existingLXC = Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXCData.vmid)" -Headers $header
}catch{}

if($existingLXC -ne $null -and $LXCData.force -eq 0){
    throw "LXC with VMID: $($LXCData.vmid) already exists. Use Force parameter to overwrite this LXC."

}elseif($existingLXC -ne $null -and $LXCData.force -eq 1){

    Write-host "Deleting existing LXC with VMID: $($LXCData.vmid)"
    $LXCDestroyAsyncTask =Invoke-RestMethod -Method DELETE -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXCData.vmid)" -Headers $header

    $count = 1;
    $maxCount = 10;
    $TaskID = $LXCDestroyAsyncTask.Data;

    DO
    {
        Write-Host "Checking if LXC has finished Deleting.."
        $LXCDestroyAsyncTaskStatus = (Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/tasks/$($TaskID)/status" -Headers $header).data
    
        if($LXCDestroyAsyncTaskStatus.status -eq "stopped"){
    	    if($LXCDestroyAsyncTaskStatus.exitstatus -ne "OK"){
        	    Write-Error "LXC destroy task finished with error: $($LXCDestroyAsyncTaskStatus.exitstatus)"
            }else{
        	    Write-Host "LXC destroy task has successfully completed!"
            }
        
            break;
        }
    
	    Write-Host "LXC destroy task has not finished yet, retrying in 5 seconds.."
        Write-Host "Task Status: $($LXCDestroyAsyncTaskStatus.status)"
        sleep 5
    
        If($count -gt $maxCount) {
          Write-Warning "Task Timed out!"
          break;
        }
        $count++

    } While ($count -le $maxCount)
}

Write-Host ""

Write-Host "New LXC Summary:"

$LXCData | Convertto-json -depth 10

$LXCCreateAsyncTask = (Invoke-RestMethod -Method POST -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc" -Headers $header -Body $LXCData)


$count = 1;
$maxCount = 10;

Write-Host ""

DO
{
 
 $TaskID = $LXCCreateAsyncTask.Data;
    Write-Host "Checking if LXC has finished creating.."
    $LXCCreateAsyncTaskStatus = (Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/tasks/$($TaskID)/status" -Headers $header).data
    
    if($LXCCreateAsyncTaskStatus.status -eq "stopped"){
    	if($LXCCreateAsyncTaskStatus.exitstatus -ne "OK"){
        	Write-Error "LXC create task finished with error: $($LXCCreateAsyncTaskStatus.exitstatus)"
        }else{
        	Write-Host "LXC create task has successfully completed!"
        }
        
        break;
    }
    
	Write-Host "LXC create task has not finished yet, retrying in 5 seconds.."
    Write-Host "Task Status: $($LXCCreateAsyncTaskStatus.status)"
    sleep 5
    
    If($count -gt $maxCount) {
      Write-Warning "Task Timed out!"
      break;
    }
    $count++

} While ($count -le $maxCount)
