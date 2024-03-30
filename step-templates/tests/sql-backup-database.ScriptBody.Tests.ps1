$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

. "$PSScriptRoot\..\sql-backup-database.ScriptBody.ps1"

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

  BeforeAll {
    $script:BackupDirectory = "C:\Backups"
    $script:DatabaseName = "ExampleDB"
    $script:StartDate = Get-Date
    $script:timestampFormat = "yyyy-MM-dd-HHmmss"
    $script:challengingFilenames = @(
        # similar DB name noted during PR review
        "ExampleDB_final_2024-03-18-1030.bak",
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
  }

  Context "ApplyRetentionPolicy functionality for single device backups" {
    BeforeAll {
      $Devices = 1
      $IncrementalFiles = 10
      $FullBackupFiles = 10
      SetupTestEnvironment -BackupDirectory $BackupDirectory -DatabaseName $DatabaseName -IncrementalFiles $IncrementalFiles -FullBackupFiles $FullBackupFiles -StartDate $StartDate -Devices $Devices -timestampFormat $timestampFormat -challengingFilenames $challengingFilenames
    }

    It "Retains the specified number of the most recent backups"  {
      $RetentionPolicyCount = 3

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      $extension = '.bak'
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }
      $retainedFiles.Count | Should Be $RetentionPolicyCount
    }

    It "Does not delete any files when RetentionPolicyCount is undefined" {
      $InitialFileCount = (Get-ChildItem -Path $BackupDirectory).Count

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      $FinalFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      $FinalFileCount | Should Be $InitialFileCount
    }

    It "Does not delete any files when RetentionPolicyCount is 0" {
      $InitialFileCount = (Get-ChildItem -Path $BackupDirectory).Count

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount 0 -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      $FinalFileCount = (Get-ChildItem -Path $BackupDirectory).Count
      $FinalFileCount | Should Be $InitialFileCount
    }

    It "Retains only the most recent backup when the RetentionPolicyCount is 1" {
      $RetentionPolicyCount = 1

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      $extension = '.bak'
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"
      $retainedFiles = @(Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern })
      $retainedFiles.Count | Should Be $RetentionPolicyCount
    }

    It "Does not delete files that do not match the backup file naming pattern" {
      # Define the extension based on whether we're dealing with incremental backups or full backups
      $extension = '.bak'
      # Define the regex pattern to match the backup files
      $regexPattern = "^${DatabaseName}_\d{4}-\d{2}-\d{2}-\d{6}${extension}$"

      # Count files that do not match the backup file naming convention before applying the retention policy
      $initialUnrelatedFileCount = @(Get-ChildItem -Path $BackupDirectory -File | Where-Object { -not ($_.Name -match $regexPattern) }).Count

      # Apply the retention policy
      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount 3 -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      # Count files that do not match the backup file naming convention after applying the retention policy
      $finalUnrelatedFileCount = @(Get-ChildItem -Path $BackupDirectory -File | Where-Object { -not ($_.Name -match $regexPattern) }).Count

      # The count of unrelated files should remain the same before and after applying the retention policy
      $finalUnrelatedFileCount | Should Be $initialUnrelatedFileCount
    }

    It "Retains the specified number of the most recent incremental backups" {
      $RetentionPolicyCount = 5

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $true -Devices $Devices -timestampFormat $timestampFormat

      $extension = '.trn'
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      $retainedFiles = @(Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern })
      $retainedFiles.Count | Should Be $RetentionPolicyCount
    }

    AfterAll {
      Remove-Item -Path $BackupDirectory -Recurse -Force
    }
  }

  Context "ApplyRetentionPolicy functionality for multi-device backups" {
    BeforeAll {
      $Devices = 4
      SetupTestEnvironment -BackupDirectory $BackupDirectory -DatabaseName $DatabaseName -IncrementalFiles $IncrementalFiles -FullBackupFiles $FullBackupFiles -StartDate $StartDate -Devices $Devices -timestampFormat $timestampFormat -challengingFilenames $challengingFilenames
    }

    It "Retains the specified number of the most recent backups" {
      $RetentionPolicyCount = 3

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $false -Devices $Devices -timestampFormat $timestampFormat

      $extension = '.bak'
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }
      $totalExpectedRetainedFiles = $RetentionPolicyCount * $Devices
      $retainedFiles.Count | Should Be $totalExpectedRetainedFiles
    }

    It "Does not delete files that do not match the backup file naming pattern for multiple devices" {
      $RetentionPolicyCount = 5 # Assuming some files are eligible for deletion

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $true -Devices $Devices -timestampFormat $timestampFormat

      $RemainingChallengingFiles = Get-ChildItem -Path $BackupDirectory | Where-Object { $challengingFilenames -contains $_.Name }
      $RemainingChallengingFileCount = $RemainingChallengingFiles.Count
      $RemainingChallengingFileCount | Should Be $challengingFilenames.Count
    }

    It "Correctly retains the specified number of the most recent incremental backups for multiple devices" {
      $RetentionPolicyCount = 5
      $Incremental = $true

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount $RetentionPolicyCount -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      $extension = '.trn'
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }
      $totalExpectedRetainedFiles = $RetentionPolicyCount * $Devices
      $retainedFiles.Count | Should Be $totalExpectedRetainedFiles
    }

    AfterAll {
      Remove-Item -Path $BackupDirectory -Recurse -Force
    }
  }
}
