$driveLetter = $OctopusParameters["driveLetter"]
$cleanupSwitch = $OctopusParameters["cleanupSwitch"]

#REM  ORIGINAL AUTHOR JAMES FOX 
#REM SOURCE http://technet.microsoft.com/en-us/library/ff630161(WS.10).aspx

#  DECLARATIONS
$SOURCEEXE = ""
$SOURCEMUI = ""
# END DECLARATIONS 

# SETUP TEMPORARY ENVIROMENT VARIABLES FOR COPY PROCESS
$DCLEANMGR = "$env:systemroot\System32"
$DCLEANMGRMUI = "$env:systemroot\System32\en-US"

# $PATH TO MUI FILE          WINDOWS 2008 R2 64bit oR 2012
if (Test-Path $env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui)
{
$SOURCEMUI = "$env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui"
}

# $PATH TO EXE FILE          WINDOWS 2008 R2 64bit oR 2012
if (Test-Path $env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe)
{
  $SOURCEEXE = "$env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe"
}


# $PATH TO MUI FILE       WINDOWS 2008 64bit
if (Test-Path $env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui)
{
	$SOURCEMUI = "$env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui"
}
# $PATH TO EXE FILE       WINDOWS 2008 64bit
if (Test-Path $env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe)
{
	$SOURCEEXE = "$env:systemroot\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe"
}

# $PATH TO MUI FILE   WINDOWS 2008 32bit
if (Test-Path $env:systemroot\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui)
{
	$SOURCEMUI = "$env:systemroot\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui"
}
# $PATH TO EXE FILE   WINDOWS 2008 32bit
if (Test-Path $env:systemroot\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe)
{
	$SOURCEEXE = "$env:systemroot\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe"
}

# COPY PROCESS 
# THIS SECTION SHOULD NEVER HAPPEN ON WINDOWS 2003 SERVER BECAUSE CLEANMGR.EXE IS ALWAYS INSTALLED
# TEST AND COPY IF CLEANMGR.EXE DOES NOT EXIST IN EXPECTED LOCATION COPY FROM SOURCE EXE AND MUI
if (!(Test-Path $env:systemroot\SYSTEM32\cleanmgr.exe))
{
  xcopy $SOURCEMUI $DCLEANMGRMUI /y
}
if (!(Test-Path $env:systemroot\SYSTEM32\cleanmgr.exe))
{
  xcopy $SOURCEEXE $DCLEANMGR /y
}

# RUN EXE AND CLEAN DRIVE MAX CLEANUP
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$env:systemroot\SYSTEM32\CLEANMGR.EXE"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = "/d$driveLetter /$cleanupSwitch"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
Write-Host "stdout: $stdout"
Write-Host "stderr: $stderr"
Write-Host "Exit Code: " + $p.ExitCode
