$winswPath = $OctopusParameters["winsw-path"]
$winswFilename = $OctopusParameters["winsw-filename"]
$winswFullPath = "$winswPath\$winswFilename"
$winswUrl = $OctopusParameters["winsw-url"]
$winswAutoInstall = $OctopusParameters["winsw-auto-install"]

Write-Host "Checking to ensure WinSW is installed."
Write-Host "For more information on WinSW check out https://github.com/winsw/winsw"

Write-Host "WinSW should be installed at $winswFullPath"
Write-Host "Checking to ensure base path is located at $winswPath"

if (-not (Test-Path -LiteralPath "$winswPath" -PathType Container)) {
	Write-Host "Path was not found. Creating the directory now."
    
    New-Item -Path "$winswPath" -ItemType Directory
    
    Write-Host "Directory created."
}


if (-not (Test-Path -LiteralPath "$winswFullPath" -PathType Leaf)) {

	Write-Host "WinSW was not found at '$winswFullPath'. Check to see if auto install flag is true."
    
    if ($winswAutoInstall -eq $true) {
    	
        Write-Host "Flag is true, installing WinSW from $winswUrl to $winswFullPath"
        
        if ($winswUrl -eq $false) {
        	
            Write-Error "WinSW download URL is not set."
            
        } else {
        	
            Invoke-WebRequest -Uri $OctopusParameters["winsw-url"] -OutFile "$winswFullPath"
        
        	Write-Host "WinSW installed at $winswPath."
        }
        
    } else {
    	
        Write-Error "Flag is false, you will need to install WinSW to $winswFullPath."
        
    }
}