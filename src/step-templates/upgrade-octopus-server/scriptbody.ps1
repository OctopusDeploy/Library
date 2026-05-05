[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function GetLatestVersionOrSpecificVersionOfOctopusServer() 
{
    if([string]::IsNullOrEmpty($SpecificOctopusServerVersionToInstall))
    {
        Write-Host "No specific version has been selected, getting latest version from octopusdeploy.com"
        $versions = Invoke-WebRequest https://octopusdeploy.com/download/upgrade/v3 -UseBasicParsing | ConvertFrom-Json
        $version = $versions[-1].Version
        return $version
    }
    else 
    {
    	Write-Host "Specific version has been selected"
        return $SpecificOctopusServerVersionToInstall
    }
}

Function GetCurrentlyInstalledVersionOfOctopusServer() 
{
    $InstalledVersion = (get-item "$InstallPath\Octopus.Server.exe").VersionInfo.fileversion
    return $installedVersion
}

Function DownloadOctopusServer([string] $versionNumber) 
{ 
    Write-Host "Downloading Octopus Server version $versionNumber"
    $tempFile = [System.IO.Path]::GetTempFileName()
  	try
    {
        (New-Object System.Net.WebClient).DownloadFile("https://download.octopusdeploy.com/octopus/Octopus.$versionNumber-x64.msi", $tempFile)
    }
    catch
    {
        Write-Host "Exception occurred"
        echo $_.Exception|format-list -force
    }
    Write-Host "Download completed"
    return $tempFile
}

Function StopOctopusServer() 
{
    Write-Host "Stopping Server"
    . "$InstallPath\Octopus.Server.exe" service --stop --console --instance $InstanceName
}

Function InstallOctopusServer([object] $tempFile)
{
    Write-Host "Installing ..."
    msiexec /i $tempFile /quiet | Out-Null
}

Function RemoveTempFile([object] $temporaryFile)
{   
    Write-Host "Deleting downloaded installer"
    Remove-Item $temporaryFile
}

Function StartOctopusServer()
{
    Write-Host "Starting Octopus Server"
    . "$InstallPath\Octopus.Server.exe" service --start --console --instance $InstanceName
}

Function InstallSetVersionOnOctopusServer([string] $currentlyInstalledVersion, [string] $selectedVersionToInstall){

      Write-Host "Currently installed version: $currentlyInstalledVersion"
      Write-Host "Selected version to install: $selectedVersionToInstall" 

      $tempFile = DownloadOctopusServer $selectedVersionToInstall
      StopOctopusServer
      InstallOctopusServer $tempFile
      RemoveTempFile $tempFile
      StartOctopusServer
}

Function StartInstallationOfOctopusServer () {

  ## Get the current state of Octopus Server
  $selectedVersionToInstall = GetLatestVersionOrSpecificVersionOfOctopusServer 
  $currentlyInstalledVersion = GetCurrentlyInstalledVersionOfOctopusServer


  if([version]$selectedVersionToInstall -eq [version]$currentlyInstalledVersion)
  {
      Write-host "Octopus Server has already been installed with version $currentlyInstalledVersion"   
  }
  else  
  {
    InstallSetVersionOnOctopusServer $currentlyInstalledVersion $selectedVersionToInstall
  }
}

StartInstallationOfOctopusServer