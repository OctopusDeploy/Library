
# Jim (Dimitrios) Andrakakis
# dandraka.com
# December 2020

param([int]$pSpaceGB = $fschkSpaceGB, 
	[int]$pSpacePercent = $fschkSpacePercent, 
    [string]$pDrives = $fschkDrives)

# ================= PARAMETERS, CONSTANTS ETC =================

$ErrorActionPreference = "Stop"
Clear-Host

$win32_logicaldisk_LocalDiskDriveType = 3

Write-Host "Parameters: SpaceGB '$pSpaceGB'"
Write-Host "Parameters: SpacePercent '$pSpacePercent'"
Write-Host "Parameters: Drives '$pDrives'"

[bool]$checkSpaceAbsolute = $false
[bool]$checkSpacePercent = $false
[bool]$checkAllDrives = $true
$driveList = New-Object System.Collections.ArrayList

# ================= SANITY CHECKS =================

$allDrives = get-wmiobject -class win32_logicaldisk | Where-Object { $_.DriveType -eq $win32_logicaldisk_LocalDiskDriveType } 
Write-Host "Drives found in the system: $($allDrives | ForEach-Object { $_.DeviceID })"

if ($pSpaceGB -gt 0) {
    $checkSpaceAbsolute = $true
    Write-Host "Will check that space > $pSpaceGB"
}

if ($pSpacePercent -gt 0) {
    $checkSpacePercent = $true
    Write-Host "Will check that space > $pSpacePercent %"
}

if ((-not $checkSpaceAbsolute) -and (-not $checkSpacePercent)) {
    Write-Error "Neither Space(GB) nor Space(%) check was specified. Please specify at least one."
}

if ([string]::IsNullOrWhiteSpace($pDrives)) {
    foreach($d in $allDrives) { $driveList.Add($d) | Out-Null }
    Write-Host "Will check all fixed drives $($driveList | ForEach-Object { $_.DeviceID + " " })"
}
else {
    $checkAllDrives = $false
    foreach($d in $allDrives) { if ($pDrives.Contains($d.DeviceID)) { $driveList.Add($d) | Out-Null | Out-Null } }
    Write-Host "Will check fixed drives $($driveList | ForEach-Object { $_.DeviceID + " " })"
}

if ($driveList.Count -eq 0) {
    Write-Error "No drives were found or, most likely, the drive list parameter does not contain any of the existing drives."
}

# ================= RUN CHECKS =================
foreach($d in $driveList) {
    $driveDescr = "$($d.DeviceID) [$($d.VolumeName)]"
    $pDrivespaceGBFree = [Math]::Round(($d.FreeSpace / [Math]::Pow(1024,3)), 1)
    $pDrivespaceGBTotal = [Math]::Round(($d.Size / [Math]::Pow(1024,3)), 1)
    $pDrivespacePercentFree = [Math]::Round($pDrivespaceGBFree / $pDrivespaceGBTotal,1) * 100
    Write-Host "Drive $driveDescr : Free $pDrivespaceGBFree GB ($pDrivespacePercentFree%), Total $pDrivespaceGBTotal GB"

    if ($checkSpaceAbsolute) {
        if ($pDrivespaceGBFree -lt $pSpaceGB) { 
            Write-Error "Drive $driveDescr has less than the required space ($pSpaceGB GB)"
        }
    }
    if ($checkSpacePercent) {
        if ($pDrivespacePercentFree -lt $pSpacePercent) { 
            Write-Error "Drive $driveDescr has less than the required space ($pSpacePercent %)"
        }
    }
}