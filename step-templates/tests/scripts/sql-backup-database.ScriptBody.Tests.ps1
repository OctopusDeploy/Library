$ErrorActionPreference = "Stop";
Set-StrictMode -Version "Latest";

# Assuming ApplyRetentionPolicy function is defined in a script file named 'ApplyRetentionPolicy.ps1'
# . '.\ApplyRetentionPolicy.ps1'

Describe "ApplyRetentionPolicy Tests" {

  BeforeAll {
    # Define the path to the backup directory for testing
    $BackupDirectory = "C:\Backups" #"$env:TEMP\TestBackups"
    $DatabaseName = "ExampleDB"
    $IncrementalFiles = 10 # Number of incremental backup files
    $FullBackupFiles = 10
    $StartDate = Get-Date
    $Devices = 1 # Assume a single device for simplicity, adjust as needed for your tests
    $timestampFormat = "yyyy-MM-dd-HHmmss"

    # Clean the backup directory to start fresh
    if (Test-Path -Path $BackupDirectory) {
      Remove-Item -Path "$BackupDirectory\*" -Recurse -Force
    }
    else {
      New-Item -ItemType Directory -Path $BackupDirectory
    }

    # Array of challenging filenames with comments explaining the challenge they create
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

    # Function to create mock backup files
    function CreateMockBackupFiles {
      param(
        $fullBackupFiles,
        $incrementalFiles,
        $startDate,
        $backupDirectory,
        $databaseName
      )

      # Helper function to generate a random time
      function Get-RandomTime {
        $hours = Get-Random -Minimum 0 -Maximum 23
        $minutes = Get-Random -Minimum 0 -Maximum 59
        $seconds = Get-Random -Minimum 0 -Maximum 59
        return "{0:D2}{1:D2}{2:D2}" -f $hours, $minutes, $seconds  # Updated format here
    }


      function CreateBackupFiles {
        param(
            $numFiles,
            $fileExtension
        )

        $currentDate = $startDate
        for ($i = 0; $i -lt $numFiles; $i++) {
            $daysToSubtract = Get-Random -Minimum 1 -Maximum 6
            $currentDate = $currentDate.AddDays(-$daysToSubtract)
            $randomTime = Get-RandomTime
            $dateSuffix = $currentDate.ToString("yyyy-MM-dd") + "-" + $randomTime
            $fileName = "$databaseName" + "_$dateSuffix" + $fileExtension
            $filePath = Join-Path -Path $backupDirectory -ChildPath $fileName
            New-Item -Path $filePath -ItemType "file" -Force | Out-Null
        }
      }

      # Create full backup files (.bak)
      CreateBackupFiles -numFiles $fullBackupFiles -fileExtension ".bak"

      # Create incremental backup files (.trn)
      CreateBackupFiles -numFiles $incrementalFiles -fileExtension ".trn"
    }

    # Create correct backup files
    CreateMockBackupFiles $FullBackupFiles $IncrementalFiles $StartDate $BackupDirectory $DatabaseName

    # Create challenging files in the specified directory
    foreach ($filename in $challengingFilenames) {
      $filePath = Join-Path -Path $BackupDirectory -ChildPath $filename
      New-Item -Path $filePath -ItemType "file" -Force | Out-Null
    }
  }

  Context "ApplyRetentionPolicy functionality" {
    It "Retains the specified number of the most recent backups and removes older backups" {

      # Variables to match the ApplyRetentionPolicy call
      $Incremental = $false
      $extension = if ($Incremental) { '.trn' } else { '.bak' }
      $timestampFormat = "yyyy-MM-dd-HHmmss"
      $devicePattern = if ($Devices -gt 1) { "(_\d+)" } else { "" }
      $dateRegex = $timestampFormat -replace "yyyy", "\d{4}" -replace "MM", "\d{2}" -replace "dd", "\d{2}" -replace "HH", "\d{2}" -replace "mm", "\d{2}" -replace "ss", "\d{2}"
      $regexPattern = "^${DatabaseName}_${dateRegex}${devicePattern}${extension}$"

      ApplyRetentionPolicy -BackupDirectory $BackupDirectory -dbName $DatabaseName -RetentionPolicyCount 5 -Incremental $Incremental -Devices $Devices -timestampFormat $timestampFormat

      # Filter files using the same regex pattern as ApplyRetentionPolicy
      $retainedFiles = Get-ChildItem -Path $BackupDirectory -Filter "*$extension" | Where-Object { $_.Name -match $regexPattern }

      $retainedFiles.Count | Should Be 5
    }
  }

  AfterAll {
    # Clean up test environment
    Remove-Item -Path $BackupDirectory -Recurse -Force
  }
}
