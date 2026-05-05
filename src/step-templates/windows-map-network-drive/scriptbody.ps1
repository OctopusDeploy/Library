#http://gallery.technet.microsoft.com/scriptcenter/Powershell-Map-utility-to-444c1c95
function Map ($computer){ 
 
function GetDriveType($DriveCode) { 
    switch ($DriveCode) 
        { 0 {"Unknown"}  
        1 {"No root directory"}  
        2 {"Removable Disk"}  
        3 {"Local Disk"}  
        4 {"Network Drive"}  
        5 {"Compact Disk"}  
        6 {"RAM Disk"}  
        } # end switch 
    } # end function GetDriveType 
 
if ($computer -eq $null) {$computer='localhost'} 
Get-WmiObject -Class win32_logicaldisk -ComputerName $computer | select DeviceID, VolumeName, ` 
    @{n='DriveType'; e={GetDriveType($_.driveType)}}, ` 
    @{n='Size';e={"{0:F2} GB" -f ($_.Size / 1gb)}}, `     
    @{n='FreeSpace';e={"{0:F2} GB" -f ($_.FreeSpace / 1gb)}} | Format-Table 
 
} 

$map = new-object -ComObject WScript.Network
if (!(Test-Path $DriveLetter))
{
	$map.MapNetworkDrive($DriveLetter, $MapPath, $MapPersist, $MapUser, $MapPass)
	Write-Host "Drive $DriveLetter mapped to $MapPath as user $MapUser."
}
else
{
    Write-Host "Drive $DriveLetter already in use."
}

Map .