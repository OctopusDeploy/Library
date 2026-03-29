function Get-Parameter($Name, $Default, [switch]$Required) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

$toolsDir = Get-Parameter "toolsDir" -Required
$sourceFile = Get-Parameter "sourceFile" -Required
$transformFile = Get-Parameter "transformFile" -Required
$destFile = Get-Parameter "destFile" -Required

if(!(Test-Path $toolsDir)){
    New-Item -Path $toolsDir -ItemType Directory
}
$nugetDestPath = Join-Path -Path $toolsDir -ChildPath nuget.exe
if(!(Test-Path $nugetDestPath)){
    Write-Output 'Downloading nuget.exe'
	# download nuget
    Invoke-WebRequest 'http://nuget.org/nuget.exe' -OutFile $nugetDestPath
    # double check that it was written to disk
    if(!(Test-Path $nugetDestPath)){
        throw 'unable to download nuget'
    }
}

$xdtExe = (Get-ChildItem -Path $toolsDir -Include 'SlowCheetah.Xdt.exe' -Recurse) | Select-Object -First 1

if(!$xdtExe){
    Write-Output 'Downloading xdt since it was not found in the tools folder'
     # nuget install SlowCheetah.Xdt -Prerelease -OutputDirectory toolsDir\
    $nugetInstallCmdArgs = @('install','SlowCheetah.Xdt','-Prerelease','-OutputDirectory',(Resolve-Path $toolsDir).ToString())

    Write-Output ('Calling nuget.exe to download SlowCheetah.Xdt with the following args: [{0} {1}]' -f $nugetDestPath, ($nugetInstallCmdArgs -join ' '))
    &($nugetDestPath) $nugetInstallCmdArgs

    $xdtExe = (Get-ChildItem -Path $toolsDir -Include 'SlowCheetah.Xdt.exe' -Recurse) | Select-Object -First 1

    if(!$xdtExe){
        throw ('SlowCheetah.Xdt not found')
    }

    # copy the xdt assemlby if the xdt directory is missing it
    $xdtDllExpectedPath = (Join-Path $xdtExe.Directory.FullName 'Microsoft.Web.XmlTransform.dll')

    if(!(Test-Path $xdtDllExpectedPath)){
        # copy the xdt.dll next to the slowcheetah .exe
        $xdtDll = (Get-ChildItem -Path $toolsDir -Include 'Microsoft.Web.XmlTransform.dll' -Recurse) | Select-Object -First 1

        if(!$xdtDll){
		    throw 'Microsoft.Web.XmlTransform.dll not found'
		}

        Copy-Item -Path $xdtDll.Fullname -Destination $xdtDllExpectedPath
    }
}

$cmdArgs = @((Resolve-Path $sourceFile).ToString(),
            (Resolve-Path $transformFile).ToString(),
            (Resolve-Path $destFile).ToString())

Write-Output ('Calling slowcheetah.xdt.exe with the args: [{0} {1}]' -f $xdtExe, ($cmdArgs -join ' '))
&($xdtExe) $cmdArgs
