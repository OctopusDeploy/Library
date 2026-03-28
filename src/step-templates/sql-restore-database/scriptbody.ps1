$ServerName = $OctopusParameters['Server']
$DatabaseName = $OctopusParameters['Database']
$BackupDirectory = $OctopusParameters['BackupDirectory']
$CompressionOption = [int]$OctopusParameters['Compression']
$Devices = [int]$OctopusParameters['Devices']
$Stamp = $OctopusParameters['Stamp']
$SqlLogin = $OctopusParameters['SqlLogin']
$SqlPassword = $OctopusParameters['SqlPassword']
$DateFormat = $OctopusParameters['DateFormat']
$Separator = $OctopusParameters['Separator']
$ErrorActionPreference = "Stop"

function ConnectToDatabase()
{
    param($server, $SqlLogin, $SqlPassword)
        
    if ($SqlLogin -ne $null) {

        if ($SqlPassword -eq $null) {
            throw "SQL Password must be specified when using SQL authentication."
        }
    
        $server.ConnectionContext.LoginSecure = $false
        $server.ConnectionContext.Login = $SqlLogin
        $server.ConnectionContext.Password = $SqlPassword
    
        Write-Host "Connecting to server using SQL authentication as $SqlLogin."
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server $server.ConnectionContext
    }
    else {
        Write-Host "Connecting to server using Windows authentication."
    }

    try {
        $server.ConnectionContext.Connect()
    } catch {
        Write-Error "An error occurred connecting to the database server!`r`n$($_.Exception.ToString())"
    }
}

function AddPercentHandler {
    param($smoBackupRestore, $action)

    $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Host $dbName $action $_.Percent "%" }
    $completedEventHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] { Write-Host $_.Error.Message}
        
    $smoBackupRestore.add_PercentComplete($percentEventHandler)
    $smoBackupRestore.add_Complete($completedEventHandler)
    $smoBackupRestore.PercentCompleteNotification=10
}

function CreateDevice {
    param($smoBackupRestore, $directory, $name)

    $devicePath = Join-Path $directory ($name)
    $smoBackupRestore.Devices.AddDevice($devicePath, "File")    
    return $devicePath
}

function CreateDevices {
    param($smoBackupRestore, $devices, $directory, $dbName)
        
    $targetPaths = New-Object System.Collections.Generic.List[System.String]
    
    if ($devices -eq 1){
        $deviceName = $dbName + $Separator + $timestamp + ".bak"
        $targetPath = CreateDevice $smoBackupRestore $directory $deviceName
        $targetPaths.Add($targetPath)
    } else {
        for ($i=1; $i -le $devices; $i++){
            $deviceName = $dbName + "_" + $timestamp + "_" + $i + ".bak"
            $targetPath = CreateDevice $smoBackupRestore $directory $deviceName
            $targetPaths.Add($targetPath)
        }
    }
    return $targetPaths
}

function RelocateFiles{
    param($smoRestore)
    
    foreach($file in $smoRestore.ReadFileList($server))
    {
        $relocateFile = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile
        $relocateFile.PhysicalFileName = $server.Settings.DefaultFile + $file.LogicalName + [System.IO.Path]::GetExtension($file.PhysicalName)
        $relocateFile.LogicalFileName = $file.LogicalName
        $smoRestore.RelocateFiles.Add($relocateFile)
    }
}

function RestoreDatabase {
    param($dbName, $devices)

    $smoRestore = New-Object Microsoft.SqlServer.Management.Smo.Restore
    $targetPaths = CreateDevices $smoRestore $devices $BackupDirectory $dbName $timestamp

    Write-Host "Attempting to restore database $ServerName.$dbName from:"
    $targetPaths
    Write-Host ""

    foreach ($path in $targetPaths) {
        if (-not (Test-Path $path)) {
            Write-Host "Cannot find backup device "($path)
            return          
        }
    }
    
    if ($server.Databases[$dbName] -ne $null)  
    {  
        $server.KillAllProcesses($dbName)
        $server.KillDatabase($dbName)
    }

    $smoRestore.Action = "Database"
    $smoRestore.NoRecovery = $false;
    $smoRestore.ReplaceDatabase = $true;
    $smoRestore.Database = $dbName

    RelocateFiles $smoRestore
    
    try {
        AddPercentHandler $smoRestore "restored"        
        $smoRestore.SqlRestore($server)
    } catch {
        Write-Error "An error occurred restoring the database!`r`n$($_.Exception.ToString())"
    }
        
    Write-Host "Restore completed successfully."
}

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null
 
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName

ConnectToDatabase $server $SqlLogin $SqlPassword

$database = $server.Databases | Where-Object { $_.Name -eq $DatabaseName }
$timestamp = if(-not [string]::IsNullOrEmpty($Stamp)) { $Stamp } else { Get-Date -format $DateFormat }

RestoreDatabase $DatabaseName $Devices