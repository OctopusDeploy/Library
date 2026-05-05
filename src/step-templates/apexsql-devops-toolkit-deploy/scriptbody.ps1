$schemaSyncScript = ''
$dataSyncScript = ''
$schemaSyncQuery = ''
$dataSyncQuery= ''
$query = ''

function AddArtifact() {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$artifact
    )
    if (Test-Path $artifact) {
        New-OctopusArtifact $artifact
    }
}

function Get-ParamValue
{
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $ParamName
    )
    if($OctopusParameters -and ($OctopusParameters["$($ParamName)"] -ne $null))
    {
        # set the variable value
        return $OctopusParameters["$($ParamName)"]
    }
    else
    {
        # warning
        return $null
    }
}

$exportPath = '#{ExportPath}'
$PackageDownloadStepName = '#{PackageDownloadStepName}'

$projectId = $OctopusParameters["Octopus.Project.Id"]
$releaseNumber = $OctopusParameters["Octopus.Release.Number"]
$nugetPackageId = $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Package.NuGetPackageId"]
$exportPath = Join-Path (Join-Path $exportPath $projectId) $releaseNumber

$defaultSchemaSyncScript = $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Output.Package.InstallationDirectoryPath"] + '\SchemaSyncScript.sql'
$defaultDataSyncScript = $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Output.Package.InstallationDirectoryPath"] + '\DataSyncScript.sql'

New-Item -Path $exportPath -Name "DeploySummary.txt" -ItemType "file" -Force | Out-Null
$deploySummary = $exportPath + "\DeploySummary.txt"

$schemaSyncScript = $exportPath + '\SchemaSyncScript.sql'
$dataSyncScript = $exportPath + '\DataSyncScript.sql'
$serverName = Get-ParamValue -ParamName 'ServerName'
  $database = Get-ParamValue -ParamName 'Database'
  $username = Get-ParamValue -ParamName 'Username'
  $password = Get-ParamValue -ParamName 'Password'
  $auth = ''
  
  if (-not ($null -eq $username -and $null -eq $password))
  {	
      $auth = " -U ""$($username)"" -P ""$($password)"""
  }
  else
  {	
      $auth = " -E"
  }

$sqlcmdProps = "sqlcmd.exe -S ""$($serverName)"" -d ""$($database)""$auth -b -i"
	if(Test-Path $schemaSyncScript) 
    {
		$result = Invoke-Expression -Command "$sqlcmdProps ""$schemaSyncScript"""
        $content = "Sync summary: " + $result
        if (Test-Path $deploySummary)
        {
        	Add-Content $deploySummary $content
        }
	}
  	if(Test-Path $dataSyncScript) 
    {
		$result = Invoke-Expression -Command "$sqlcmdProps ""$dataSyncScript"""
        $content = "Sync data summary: " + $result
        if (Test-Path $deploySummary)
        {
        	Add-Content $deploySummary $content
        }
	}

	if(Test-Path $defaultSchemaSyncScript) 
    {
		$result = Invoke-Expression -Command "$sqlcmdProps ""$defaultSchemaSyncScript"""
	}
    if(Test-Path $defaultDataSyncScript) 
    {
		$result = Invoke-Expression -Command "$sqlcmdProps ""$defaultDataSyncScript"""
	}

AddArtifact("$deploySummary")