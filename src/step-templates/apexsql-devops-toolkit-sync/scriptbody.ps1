function Get-ApexSQLToolLocation
{
    param
    (
        [Parameter(Mandatory = $true)]
        [String] $ApplicationName
    )
    $key = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ApexSQL $($ApplicationName)_is1"
    if (Test-Path "HKLM:\$Key")
    {
		$ApplicationPath = (Get-ItemProperty -Path "HKLM:\$key" -Name InstallLocation).InstallLocation
	}
    else
    {
		$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)

		$regKey= $reg.OpenSubKey("$key")
		if ($regKey)
        {
			$ApplicationPath = $regKey.GetValue("InstallLocation")
		}
        else
        {
			$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
			$regKey= $reg.OpenSubKey("$key")
			if ($regKey)
            {
				$ApplicationPath = $regKey.GetValue("InstallLocation")
			}
            else
            {
                return $null
			}
		}
	}
    if ($ApplicationPath)
    {
        return $ApplicationPath + "ApexSQL" + $ApplicationName.replace(' ','') + ".com"
    }
}

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

$exportPath = Get-ParamValue -ParamName 'ExportPath'
$PackageDownloadStepName = Get-ParamValue -ParamName 'PackageDownloadStepName'
$s2 = Get-ParamValue -ParamName 'ServerName'
$d2 = Get-ParamValue -ParamName 'Database'
$u2 = Get-ParamValue -ParamName 'Username'
$p2 = Get-ParamValue -ParamName 'Password'
$projectFilePath = Get-ParamValue -ParamName 'ProjectFilePath'
$additional = Get-ParamValue -ParamName 'Additional'

$projectId = $OctopusParameters["Octopus.Project.Id"]
$releaseNumber = $OctopusParameters["Octopus.Release.Number"]
$nugetPackageId = $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Package.NuGetPackageId"]
$exportPath = Join-Path (Join-Path $exportPath $projectId) $releaseNumber

if (-Not (Test-Path $exportPath)) { New-Item $exportPath -ItemType Directory }

$FolderList = Get-ChildItem $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Output.Package.InstallationDirectoryPath"] -Directory

Foreach($f in $Folderlist){
if ($f.Name -like '*Script*')
	{
 		$DatabaseScripts = $f.Name
 	}
}

$sfPath = $OctopusParameters["Octopus.Action[$PackageDownloadStepName].Output.Package.InstallationDirectoryPath"] + '\' + $DatabaseScripts

if($null -eq $sfPath) {
    throw "Step: '$PackageDownloadStepName' didn't download any NuGet package."
}

$schemaSyncScript = "SchemaSyncScript.sql"
$schemaSyncSummary = "SchemaSyncSummary.log"
$schemaSyncReport = "SchemaSyncReport.html"


$creds2 = ''
if ($u2 -ne $null -and $p2 -ne $null)
{
    $creds2 = "/user2:`"$($u2)`" /password2:`"$($p2)`""
}

$project = ''
if($projectFilePath -ne $null)
{
    $project = "/project: `"$($projectFilePath)`""
}

$additionalParams = ''
if($additional -ne $null)
{
    $additionalParams = $additional
}


$toolLocation = Get-ApexSQLToolLocation -ApplicationName 'Diff'
$toolParams = " /sf1:`"$($sfPath)`" /server2:`"$($s2)`" /database2:`"$($d2)`" $($creds2)"
$toolParams += " /ot:sql /on:`'$($exportPath)\$($schemaSyncScript)`'"
$toolParams += " /ot2:html /on2:`"$($exportPath)\$($schemaSyncReport)`""
$toolParams += " /cso:`"$($exportPath)\$($schemaSyncSummary)`""
$toolParams += " $($project)"
$toolParams += " $($additionalParams) /v /f"

Invoke-Expression -Command ("& `"$($toolLocation)`" $toolParams")

AddArtifact("$exportPath\$schemaSyncScript")
AddArtifact("$exportPath\$schemaSyncSummary")
AddArtifact("$exportPath\$schemaSyncReport")