$filePath = $OctopusParameters['FilePath']
$newName = $OctopusParameters['NewName']

function Test-FileLocked([string]$filePath)
{
  Rename-Item $filePath $filePath -ErrorVariable errs -ErrorAction SilentlyContinue
  return ($errs.Count -ne 0)
}

$fileExists = Test-Path -Path $filePath

if (!$fileExists)
{
  Write-Warning "File not found at $filePath"

  return
}

$fileIsLocked = Test-FileLocked($filePath)

function Wait-ForFileUnlock
{
  for ($attemptNo = 1; $attemptNo -lt 6; $attemptNo++) {
    Write-Host "Waiting for the file to become unlocked $attemptNo/5"

    Start-Sleep -Seconds 10

    $fileIsLocked = Test-FileLocked($filePath)

    if (!$fileIsLocked)
    {
      return
    }

    if ($attemptNo -eq 5) {
      Write-Error "File at location $filePath is locked and cannot be renamed"

      return
    }
  }
}

if ($fileIsLocked)
{
  Wait-ForFileUnlock
}

Rename-Item -Path $filePath -NewName $newName

Write-Host "Successfully renamed file at location: $filePath to $newName"