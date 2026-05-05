function Test-FileLocked([string]$filePath)
{
  $fileExists = Test-Path -Path $filePath
  if (!$fileExists)
  {
    return (1 -eq 0) #false
  }
  Rename-Item $filePath $filePath -ErrorVariable errs -ErrorAction SilentlyContinue
  return ($errs.Count -ne 0)
}

function Wait-ForFileUnlock([string]$filePath)
{ 
  Write-Host "Destinationfile at $filePath is locked"
    
  for ($attemptNo = 1; $attemptNo -lt 6; $attemptNo++) {
    Write-Host "Waiting for the file to become unlocked $attemptNo/5"

    Start-Sleep -Seconds 10

    $fileIsLocked = Test-FileLocked($filePath)

    if (!$fileIsLocked)
    {
      return
    }

    if ($attemptNo -eq 5) {
      Write-Error "destinationfile at location $filePath is locked and cannot be overwritten."

      return
    }
  }
}

#
#script starts here
#

$filePath = $OctopusParameters['sourcePath']
$newFilePath = $OctopusParameters['destinationPath']

$fileExists = Test-Path -Path $filePath

if (!$fileExists)
{
  Write-Error "Sourcefile not found at $filePath"

  return
}

$fileIsLocked = Test-FileLocked($newFilePath)


if ($fileIsLocked)
{
  Wait-ForFileUnlock($newFilePath)
}


$fileIsLocked = Test-FileLocked($newFilePath)
if ($fileIsLocked)
{
    return
}

Copy-Item -Path $filePath -Destination $newFilePath -Force

Write-Host "Successfully copied file at location: $filePath to $newFilePath"