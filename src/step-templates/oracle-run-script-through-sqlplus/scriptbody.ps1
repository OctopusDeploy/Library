$scriptFile = $OctopusParameters["Oracle.ScriptFile.Location"]
$server = $OctopusParameters["Oracle.Server.Name"]
$user = $OctopusParameters["Oracle.User.Name"]
$password = $OctopusParameters["Oracle.User.Password"]

Write-Host "Script File: $scriptFile"
Write-Host "Oracle Server: $server"
Write-Host "Oracle Username: $user"
Write-Host "Oracle Password not shown"

If ((Test-Path $scriptFile) -eq $true){
  Write-Host "Script file found, running on the database"
  
  $maskedConnectionString = "$user/*****@$server/$deploymentSchema"
  $unmaskedConnectionString = "$user/$password@$server"
  Write-Host "Running the script against: $maskedConnectionString"
  
  Write-Host "Adding to the top of the script file WHENEVER SQLERROR EXIT SQL.SQLCODE"
  $scriptToHandleErrors = "WHENEVER SQLERROR EXIT SQL.SQLCODE
  "
  
  $old = Get-Content $scriptFile
  Set-Content -Path $scriptFile -Value $scriptToHandleErrors
  Add-Content -Path $scriptFile -Value $old

  echo exit | sqlplus $unmaskedConnectionString @$scriptFile
}
else {
	Write-Highlight "No script file was found.  If the script file should be there please verify the location and try again."
}