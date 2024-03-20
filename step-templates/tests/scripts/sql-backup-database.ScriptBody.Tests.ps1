$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

# Assuming ApplyRetentionPolicy function is defined in a script file named 'ApplyRetentionPolicy.ps1'
# . '.\ApplyRetentionPolicy.ps1'

function SetupTestEnvironment {
  param(
    $BackupDirectory,
    $DatabaseName,
    $IncrementalFiles,
    $FullBackupFiles,
    $StartDate,
    $Devices,
    $timestampFormat,
    $challengingFilenames
  )

  # Clean the backup directory to start fresh
  if (Test-Path -Path $BackupDirectory) {
    Remove-Item -Path "$BackupDirectory\*" -Recurse -Force
  }
  else {
    New-Item -ItemType Directory -Path $BackupDirectory
  }

  # Function to generate a random time
  function Get-RandomTime {
    $hours = Get-Random -Minimum 0 -Maximum 23
    $minutes = Get-Random -Minimum 0 -Maximum 59
    $seconds = Get-Random -Minimum 0 -Maximum 59
    return "{0:D2}{1:D2}{2:D2}" -f $hours, $minutes, $seconds
  }

  function CreateBackupFiles {
    param(
      $numFiles,
      $fileExtension,
      $numDevices
    )

    for ($i = 0; $i -lt $numFiles; $i++) {
      $daysToSubtract = Get-Random -Minimum 1 -Maximum 6
      $currentDate = $StartDate.AddDays(-$daysToSubtract)
      $randomTime = Get-RandomTime
      $dateSuffix = $currentDate.ToString("yyyy-MM-dd") + "-" + $randomTime

      for ($d = 1; $d -le $numDevices; $d++) {

        $deviceSuffix = if ($numDevices -gt 1) { "_$d" } else { "" }

        $fileName = "$DatabaseName" + "_$dateSuffix" + $deviceSuffix + $fileExtension
        $filePath = Join-Path -Path $BackupDirectory -ChildPath $fileName
        New-Item -Path $filePath -ItemType "file" -Force | Out-Null
      }
    }
  }

  # Create full and incremental backup files considering the number of devices
  CreateBackupFiles -numFiles $FullBackupFiles -fileExtension ".bak" -numDevices $Devices
  CreateBackupFiles -numFiles $IncrementalFiles -fileExtension ".trn" -numDevices $Devices


  # Create challenging files in the specified directory
  foreach ($filename in $challengingFilenames) {
    $filePath = Join-Path -Path $BackupDirectory -ChildPath $filename
    New-Item -Path $filePath -ItemType "file" -Force | Out-Null
  }
}

Describe "ApplyRetentionPolicy Tests" {

  Context "ApplyRetentionPolicy functionality for single device backups" {
    BeforeAll {
      $BackupDirectory = "C:\Backups"
      $DatabaseName = "ExampleDB"
      $IncrementalFiles = 10
      $FullBackupFiles = 10
      $StartDate = Get-Date
      $Devices = 1
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $challengingFilenames = @(
        # Similar DB name, valid timestamp. Might be confused with a backup for a different but similarly named database.
        "ExampleDB1_2024-03-18-1030.bak",
        # Same DB, different valid timestamp. Tests accuracy of timestamp matching.
        "ExampleDB_2024-03-19-1030.bak",
        # Similar timestamp format, but different. Might test pattern matching robustness.
        "ExampleDB_20240318_1030.bak",
        # Different DB, valid timestamp. Should not be matched if script correctly identifies DB name.
        "TestDB_2024-03-18-1030.bak",
        # Non-backup file type with valid naming. Should be ignored by the cleanup script.
        "ExampleDB_2024-03-18-1030.log",
        # Completely unrelated file. Should always be ignored by the cleanup script.
        "RandomFile.txt",
        # Similar DB name with underscore. Might be confused with main database name if script uses loose matching.
        "Example_DB_2024-03-18-1030.bak",
        # Same DB name, lowercase. Tests case sensitivity of the script.
        "exampledb_2024-03-18-1030.bak",
        # Similar timestamp, underscore separator. Variation in timestamp format might challenge pattern matching.
        "ExampleDB_2024-03-18_1030.bak",
        # Different DB, valid timestamp for trn. Tests database name matching accuracy with incremental backups.
        "AnotherDB_2024-03-18-1030.trn"
      )
      SetupTestEnvironment -BackupDirectory $BackupDirectory -DatabaseName $DatabaseName -IncrementalFiles $IncrementalFiles -FullBackupFiles $FullBackupFiles -StartDate $StartDate -Devices $Devices -timestampFormat $timestampFormat -challengingFilenames $challengingFilenames
    }

    It "Retains the specified number of the most recent backups and removes older backups" {

      # Variables to match the ApplyRetentionPolicy call
      $RetentionPolicyCount = 5
      $Incremental = $false
      $extension = if ($Incremental) { '.trn' } else { '.bak' }
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      # Filter files using the same regex pattern as ApplyRetentionPolicy
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

      $retainedFiles.Count | Should Be $RetentionPolicyCount
    }

    It "Does not delete any files when RetentionPolicyCount is 0" {
      $InitialFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount 0 -Incremental $false -Devices $Devices -timestampFormat $timestampFormat
      $FinalFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      $FinalFileCount | Should Be $InitialFileCount
    }

    It "Does not delete files that do not match the backup file naming pattern" {
      # Assume a scenario where some backups are eligible for deletion
      $RetentionPolicyCount = 5 # Setting a policy that should trigger some deletions
      $InitialChallengingFileCount = $challengingFilenames.Count

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      # Filter for challenging filenames after policy application
      $RemainingChallengingFiles = Get-ChildItem -Path $BackupDirectory | Where-Object { $challengingFilenames -contains $_.Name }
      $RemainingChallengingFileCount = $RemainingChallengingFiles.Count

      # Verify that files not matching the backup pattern were not deleted
      $RemainingChallengingFileCount | Should Be $InitialChallengingFileCount
    }

    It "Correctly retains the specified number of the most recent incremental backups" {
      # Variables to match the ApplyRetentionPolicy call
      $RetentionPolicyCount = 5
      $Incremental = $true
      $extension = if ($Incremental) { '.trn' } else { '.bak' }
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      # Apply retention policy specifically for incremental backups
      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      # Filter files using the same regex pattern as ApplyRetentionPolicy
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

      $retainedFiles.Count | Should Be $RetentionPolicyCount
    }

    AfterAll {
      Remove-Item -Path $BackupDirectory -Recurse -Force
    }
  }

  Context "ApplyRetentionPolicy functionality for multi-device backups" {
    BeforeAll {
      $Devices = 4
      $BackupDirectory = "C:\Backups"
      $DatabaseName = "ExampleDB"
      $IncrementalFiles = 10
      $FullBackupFiles = 10
      $StartDate = Get-Date
      $Devices = 4
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $challengingFilenames = @(
        # Similar DB name, valid timestamp. Might be confused with a backup for a different but similarly named database.
        "ExampleDB1_2024-03-18-1030.bak",
        # Same DB, different valid timestamp. Tests accuracy of timestamp matching.
        "ExampleDB_2024-03-19-1030.bak",
        # Similar timestamp format, but different. Might test pattern matching robustness.
        "ExampleDB_20240318_1030.bak",
        # Different DB, valid timestamp. Should not be matched if script correctly identifies DB name.
        "TestDB_2024-03-18-1030.bak",
        # Non-backup file type with valid naming. Should be ignored by the cleanup script.
        "ExampleDB_2024-03-18-1030.log",
        # Completely unrelated file. Should always be ignored by the cleanup script.
        "RandomFile.txt",
        # Similar DB name with underscore. Might be confused with main database name if script uses loose matching.
        "Example_DB_2024-03-18-1030.bak",
        # Same DB name, lowercase. Tests case sensitivity of the script.
        "exampledb_2024-03-18-1030.bak",
        # Similar timestamp, underscore separator. Variation in timestamp format might challenge pattern matching.
        "ExampleDB_2024-03-18_1030.bak",
        # Different DB, valid timestamp for trn. Tests database name matching accuracy with incremental backups.
        "AnotherDB_2024-03-18-1030.trn"
      )
      SetupTestEnvironment -BackupDirectory $BackupDirectory -DatabaseName $DatabaseName -IncrementalFiles $IncrementalFiles -FullBackupFiles $FullBackupFiles -StartDate $StartDate -Devices $Devices -timestampFormat $timestampFormat -challengingFilenames $challengingFilenames
    }

    It "Retains the specified number of the most recent backups and removes older backups" {

      # Variables to match the ApplyRetentionPolicy call
      $Devices = 4
      $RetentionPolicyCount = 5
      $totalRetained = $Devices * $RetentionPolicyCount
      $Incremental = $false
      $extension = if ($Incremental) { '.trn' } else { '.bak' }
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      # Filter files using the same regex pattern as ApplyRetentionPolicy
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

      $retainedFiles.Count | Should Be $totalRetained
    }

    It "Does not delete any files when RetentionPolicyCount is 0" {
      $InitialFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount 0 -Incremental $false -Devices $Devices -timestampFormat $timestampFormat
      $FinalFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      $FinalFileCount | Should Be $InitialFileCount
    }

    It "Does not delete files that do not match the backup file naming pattern" {
      # Assume a scenario where some backups are eligible for deletion
      $RetentionPolicyCount = 5 # Setting a policy that should trigger some deletions
      $InitialChallengingFileCount = $challengingFilenames.Count

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      # Filter for challenging filenames after policy application
      $RemainingChallengingFiles = Get-ChildItem -Path $BackupDirectory | Where-Object { $challengingFilenames -contains $_.Name }
      $RemainingChallengingFileCount = $RemainingChallengingFiles.Count

      # Verify that files not matching the backup pattern were not deleted
      $RemainingChallengingFileCount | Should Be $InitialChallengingFileCount
    }

    It "Correctly retains the specified number of the most recent incremental backups" {
      # Variables to match the ApplyRetentionPolicy call
      $Devices = 4
      $RetentionPolicyCount = 5
      $totalRetained = $Devices * $RetentionPolicyCount
      $Incremental = $true
      $extension = if ($Incremental) { '.trn' } else { '.bak' }
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      # Apply retention policy specifically for incremental backups
      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      # Filter files using the same regex pattern as ApplyRetentionPolicy
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

      $retainedFiles.Count | Should Be $totalRetained
    }

    AfterAll {
      Remove-Item -Path $BackupDirectory -Recurse -Force
    }
  }

}
