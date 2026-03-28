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


$LXC_Force = 0
try {
  $Force = [System.Convert]::ToBoolean($OctopusParameters["Proxmox.LXC.Force"])
  
  if($Force -eq $True){
  	$LXC_Force = 1
  }
  
} catch {}

$LXCDestroyAsyncTask = (Invoke-RestMethod -Method DELETE -uri "$($BaseURL)/nodes/$($ProxmoxNode)/lxc/$($LXC_VMID)?force=$($LXC_Force)" -Headers $header)

$count = 1;
$maxCount = 10;

$TaskID = $LXCDestroyAsyncTask.Data;

DO
{
    Write-Host "Checking if LXC has finished Destroying.."
    $LXCSDestroyAsyncTaskStatus = (Invoke-RestMethod -Method GET -uri "$($BaseURL)/nodes/$($ProxmoxNode)/tasks/$($TaskID)/status" -Headers $header).data
    
    if($LXCSDestroyAsyncTaskStatus.status -eq "stopped"){
    	if($LXCSDestroyAsyncTaskStatus.exitstatus -ne "OK"){
        	Write-Error "LXC destroy task finished with error: $($LXCSDestroyAsyncTaskStatus.exitstatus)"
        }else{
        	Write-Host "LXC destroy task has successfully completed!"
        }
        
        break;
    }
    
	Write-Host "LXC destroy task has not finished yet, retring in 5 seconds.."
    Write-Host "Task Status: $($LXCSDestroyAsyncTaskStatus.status)"
    sleep 5
    
    If($count -gt $maxCount) {
      Write-Warning "Task Timed out!"
      break;
    }
    $count++

} While ($count -le $maxCount)
