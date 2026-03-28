# Proxmox Connection Variables
$ProxmoxHost = $OctopusParameters["Proxmox.Host"];
$ProxmoxPort = [int]$OctopusParameters["Proxmox.Port"];
$ProxmoxUser = $OctopusParameters["Proxmox.User"];

$ProxmoxNode = $OctopusParameters["Proxmox.Node"];

$ProxmoxTokenID = $OctopusParameters["Proxmox.TokenID"];
$ProxmoxToken = $OctopusParameters["Proxmox.Token"];

# LXC Variables
$LXC_VMID = [int]$OctopusParameters["Proxmox.LXC.VMID"];

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

$CheckLXCExists = Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXC_VMID)/status/current" -Headers $header

if($CheckLXCExists.data -eq $null){
	throw "The LXC container with vmid ($LXC_VMID) does not exist!"
}


$LXC_Stop = $False
try {
  $Stop = [System.Convert]::ToBoolean($OctopusParameters["Proxmox.LXC.Stop"])
  
  if($Stop -eq $True){
  	$LXC_Stop = $True
  }
  
} catch {}

$LXCData = @{}

if($LXC_Stop -eq $True){
	$LXCStopAsyncTask = (Invoke-RestMethod -Method POST -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXC_VMID)/status/stop" -Headers $header -Body $LXCData)
} else{
	$LXCStopAsyncTask = (Invoke-RestMethod -Method POST -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXC_VMID)/status/shutdown" -Headers $header -Body $LXCData)
}

$count = 1;
$maxCount = 10;

$TaskID = $LXCStopAsyncTask.Data;

DO
{
    Write-Host "Checking if LXC has finished Shutting Down.."
    $LXCStopAsyncTaskStatus = (Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/tasks/$($TaskID)/status" -Headers $header).data
    
    if($LXCStopAsyncTaskStatus.status -eq "stopped"){
    	if($LXCStopAsyncTaskStatus.exitstatus -ne "OK"){
        	Write-Error "LXC shutdown task finished with error: $($LXCStopAsyncTaskStatus.exitstatus)"
        }else{
        	Write-Host "LXC shutdown task has successfully completed!"
        }
        
        break;
    }
    
	Write-Host "LXC shutdown task has not finished yet, retring in 5 seconds.."
    Write-Host "Task Status: $($LXCStopAsyncTaskStatus.status)"
    sleep 5
    
    If($count -gt $maxCount) {
      Write-Warning "Task Timed out!"
      break;
    }
    $count++

} While ($count -le $maxCount)
