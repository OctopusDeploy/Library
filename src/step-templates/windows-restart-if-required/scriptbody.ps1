# Sourced from https://github.com/adbertram/Random-PowerShell-Work/blob/master/Random%20Stuff/Test-PendingReboot.ps1
# Script will run only on the server with the Tentacle installed

function Test-RegistryKey($Key) {
    if (Get-Item -Path $Key -ErrorAction Ignore) {
        return $true
    }
    return $false
}

function Test-RegistryValue($Key, $Value) {
    if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
        return $true
    }
    return $false
}

function Test-RegistryValueNotNull($Key, $Value) {
    if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
        return $true
    }
    return $false
}

$IsPendingReboot = $false

# Testing Registry keys for Restarts
# an exception is thrown when Get-ItemProperty or Get-ChildItem are passed a nonexistant key path
$tests = @(
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
    { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
    { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
    { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
    { Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
    { 
		(Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Updates') -and
		(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Updates' -Name 'UpdateExeVolatile' | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0 
	}
    { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
    { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
    { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
    { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
    {
        (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName').ComputerName -ne
        (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
    }
    {
        if (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending') {
            $true
        }
    }
)

Write-Debug "Running tests to checking for reboot pending"
foreach ($test in $tests) {
    if (& $test) {
        Write-Debug "Test found reboot pending: $test"
        $IsPendingReboot = $true
        break
    }
}
    

if($IsPendingReboot -eq $true) {
    Write-Host "Restarting"
    Restart-Computer -Force
}
if($IsPendingReboot -eq $false) {
    Write-Host "No Restart required"
}
