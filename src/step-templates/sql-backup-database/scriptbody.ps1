$ErrorActionPreference = "Stop"
$EnableVerboseOutput = $false # pester does not support -Verbose; this is a workaround

function ConnectToDatabase() {
  param($server, $SqlLogin, $SqlPassword, $ConnectionTimeout)

  $server.ConnectionContext.StatementTimeout = $ConnectionTimeout

  if ($null -ne $SqlLogin) {

    if ($null -eq $SqlPassword) {
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
  }
  catch {
    Write-Error "An error occurred connecting to the database server!`r`n$($_.Exception.ToString())"
  }
}

function AddPercentHandler {
  param($smoBackupRestore, $action)

  $percentEventHandler = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] { Write-Host $dbName $action $_.Percent "%" }
  $completedEventHandler = [Microsoft.SqlServer.Management.Common.ServerMessageEventHandler] { Write-Host $_.Error.Message }

  $smoBackupRestore.add_PercentComplete($percentEventHandler)
  $smoBackupRestore.add_Complete($completedEventHandler)
  $smoBackupRestore.PercentCompleteNotification = 10
}

function CreateDevice {
  param($smoBackupRestore, $directory, $name)

  $devicePath = [System.IO.Path]::Combine($directory, $name)
  $smoBackupRestore.Devices.AddDevice($devicePath, "File")
  return $devicePath
}

function CreateDevices {
  param($smoBackupRestore, $devices, $directory, $dbName, $incremental, $timestamp)

  $targetPaths = New-Object System.Collections.Generic.List[System.String]

  $extension = ".bak"

  if ($incremental -eq $true) {
    $extension = ".trn"
  }

  if ($devices -eq 1) {
    $deviceName = $dbName + "_" + $timestamp + $extension
    $targetPath = CreateDevice $smoBackupRestore $directory $deviceName
    $targetPaths.Add($targetPath)
  }
  else {
    for ($i = 1; $i -le $devices; $i++) {
      $deviceName = $dbName + "_" + $timestamp + "_" + $i + $extension
      $targetPath = CreateDevice $smoBackupRestore $directory $deviceName
      $targetPaths.Add($targetPath)
    }
  }
  return $targetPaths
}

function BackupDatabase {
  param (
    [Microsoft.SqlServer.Management.Smo.Server]$server,
    [string]$dbName,
    [string]$BackupDirectory,
    [int]$devices,
    [int]$compressionOption,
    [boolean]$incremental,
    [boolean]$copyonly,
    [string]$timestamp,
    [string]$timestampFormat,
    [boolean]$RetentionPolicyEnabled,
    [int]$RetentionPolicyCount
  )

  $smoBackup = New-Object Microsoft.SqlServer.Management.Smo.Backup
  $targetPaths = CreateDevices $smoBackup $devices $BackupDirectory $dbName $incremental $timestamp

  Write-Host "Attempting to backup database $server.Name.$dbName to:"
  $targetPaths | ForEach-Object { Write-Host $_ }
  Write-Host ""

  if ($incremental -eq $true) {
    $smoBackup.Action = "Log"
    $smoBackup.BackupSetDescription = "Log backup of " + $dbName
    $smoBackup.LogTruncation = "Truncate"
  }
  else {
    $smoBackup.Action = "Database"
    $smoBackup.BackupSetDescription = "Full Backup of " + $dbName
  }

  $smoBackup.BackupSetName = $dbName + " Backup"
  $smoBackup.MediaDescription = "Disk"
  $smoBackup.CompressionOption = $compressionOption
  $smoBackup.CopyOnly = $copyonly
  $smoBackup.Initialize = $true
  $smoBackup.Database = $dbName

  try {
    AddPercentHandler $smoBackup "backed up"
    $smoBackup.SqlBackup($server)
    Write-Host "Backup completed successfully."

    if ($RetentionPolicyEnabled -eq $true) {
      ApplyRetentionPolicy $BackupDirectory $dbName $RetentionPolicyCount $Incremental $Devices $timestampFormat
    }
  }
  catch {
    Write-Error "An error occurred backing up the database!`r`n$($_.Exception.ToString())"
  }
}

function ApplyRetentionPolicy {
  param (
      [string]$BackupDirectory,
      [string]$dbName,
      [int]$RetentionPolicyCount,
      [bool]$Incremental = $false,
      [int]$Devices = 1,
      [string]$timestampFormat = "yyyy-MM-dd-HHmmss"
  )

  # Check if RetentionPolicyCount is defined
  if (-not $PSBoundParameters.ContainsKey('RetentionPolicyCount')) {
      Write-Host "Retention policy not applied as RetentionPolicyCount is undefined."
      return
  }

  # Set the appropriate file extension
  $extension = if ($Incremental) { '.trn' } else { '.bak' }

  # Prepare the regex pattern for matching the files
  $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
  $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
  $regexPattern = "^${dbName}_${dateRegex}${devicePattern}${extension}$"

  # Get all matching files in the directory
  $allBackups = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

  # If there are no matching backups, exit
  if (-not $allBackups) {
      Write-Host "No matching backups found."
      return
  }

  # If RetentionPolicyCount is zero, don't delete or keep any backups
  if ($RetentionPolicyCount -le 0) {
      if($EnableVerboseOutput) { # pester does not support -Verbose; this is a workaround
        Write-Host "Retention policy not applied as RetentionPolicyCount is set to 0."
      }
  } elseif ($Devices -gt 1) {
      # Group by the timestamp part (ignore the device number)
      $groupedBackups = $allBackups | Group-Object {
          # Extract the timestamp, ignoring the device part if there are multiple devices
          ($_.Name -replace "${devicePattern}${extension}$", "") -replace "^${dbName}_", ""
      }

      # Sort the groups by the timestamp
      $sortedGroups = $groupedBackups | Sort-Object Name

      # Get the groups to keep
      $groupsToKeep = $sortedGroups | Select-Object -Last $RetentionPolicyCount
      $filesToKeep = $groupsToKeep | ForEach-Object { $_.Group }

      # Flatten the collection of files to keep, ensuring that FullName is accessed correctly
      $filesToKeepFlattened = $filesToKeep | ForEach-Object { $_ | Select-Object -ExpandProperty FullName }
      $filesToDelete = $allBackups | Where-Object { $filesToKeepFlattened -notcontains $_.FullName }

      # Delete the old backups
      $filesToDelete | ForEach-Object {
          if($EnableVerboseOutput) { # pester does not support -Verbose; this is a workaround
            Write-Host "Deleting old backup: $($_.FullName)"
          }
          Remove-Item -Path $_.FullName -Force
      }

      # List the files to keep
      $filesToKeepFlattened | ForEach-Object {
          Write-Verbose "Keeping backup: $($_)"
      }

      Write-Host "Retention policy applied. Kept $RetentionPolicyCount most recent backups."
  } else {
      # Single device: simply sort the backups by timestamp
      $sortedBackups = $allBackups | Sort-Object Name

      # Get the backups to keep
      $backupsToKeep = $sortedBackups | Select-Object -Last $RetentionPolicyCount
      $filesToDelete = $allBackups | Where-Object { $backupsToKeep -notcontains $_ }

      # Delete the old backups
      $filesToDelete | ForEach-Object {
        if($EnableVerboseOutput) { # pester does not support -Verbose; this is a workaround
          Write-Host "Deleting old backup: $($_.FullName)"
        }
        Remove-Item -Path $_.FullName -Force
      }

      # List the files to keep
      $backupsToKeep | ForEach-Object {
        if($EnableVerboseOutput) { # pester does not support -Verbose; this is a workaround
          Write-Host "Keeping backup: $($_.FullName)"
        }
      }

      if($EnableVerboseOutput) { # pester does not support -Verbose; this is a workaround
        Write-Host "Retention policy applied. Kept $RetentionPolicyCount most recent backups."
      }
  }
}

function Invoke-SqlBackupProcess {
  param (
    [hashtable]$OctopusParameters
  )

  # Extracting parameters from the hashtable
  $ServerName = $OctopusParameters['Server']
  $DatabaseName = $OctopusParameters['Database']
  $BackupDirectory = $OctopusParameters['BackupDirectory']
  $CompressionOption = [int]$OctopusParameters['Compression']
  $Devices = [int]$OctopusParameters['Devices']
  $Stamp = $OctopusParameters['Stamp']
  $UseSqlServerTimeStamp = $OctopusParameters['UseSqlServerTimeStamp']
  $SqlLogin = $OctopusParameters['SqlLogin']
  $SqlPassword = $OctopusParameters['SqlPassword']
  $ConnectionTimeout = $OctopusParameters['ConnectionTimeout']
  $Incremental = [boolean]::Parse($OctopusParameters['Incremental'])
  $CopyOnly = [boolean]::Parse($OctopusParameters['CopyOnly'])
  $RetentionPolicyEnabled = [boolean]::Parse($OctopusParameters['RetentionPolicyEnabled'])
  $RetentionPolicyCount = [int]$OctopusParameters['RetentionPolicyCount']

  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null

  $server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName

  ConnectToDatabase $server $SqlLogin $SqlPassword $ConnectionTimeout

  $database = $server.Databases | Where-Object { $_.Name -eq $DatabaseName }
  $timestampFormat = "yyyy-MM-dd-HHmmss"
  if ($UseSqlServerTimeStamp -eq $true) {
    $timestampFormat = "yyyyMMdd_HHmmss"
  }
  $timestamp = if (-not [string]::IsNullOrEmpty($Stamp)) { $Stamp } else { Get-Date -format $timestampFormat }

  if ($null -eq $database) {
    Write-Error "Database $DatabaseName does not exist on $ServerName"
  }

  if ($Incremental -eq $true) {
    if ($database.RecoveryModel -eq 3) {
      write-error "$DatabaseName has Recovery Model set to Simple. Log backup cannot be run."
    }

    if ($database.LastBackupDate -eq "1/1/0001 12:00 AM") {
      write-error "$DatabaseName has no Full backups. Log backup cannot be run."
    }
  }

  if ($RetentionPolicyEnabled -eq $true -and $RetentionPolicyCount -gt 0) {
    if (-not [int]::TryParse($RetentionPolicyCount, [ref]$null) -or $RetentionPolicyCount -le 0) {
      Write-Error "RetentionPolicyCount must be an integer greater than zero."
    }
  }

  BackupDatabase $server $DatabaseName $BackupDirectory $Devices $CompressionOption $Incremental $CopyOnly $timestamp $timestampFormat $RetentionPolicyEnabled $RetentionPolicyCount
}

if (Test-Path -Path "Variable:OctopusParameters") {
  Invoke-SqlBackupProcess -OctopusParameters $OctopusParameters
}
