@echo off
setlocal
set EXDIR=%~dp0scriptcs
set PATH=%PATH%;%EXDIR%\tools
set ISTEAMCITY="false"
IF "%1" NEQ "" set ISTEAMCITY=%1

scriptcs -v >nul 2>&1 && ( echo scriptcs is installed & goto run ) || ( echo scriptcs is not installed )

echo Installing scriptcs
set ZIPFILE=%~dp0scriptcs.zip
powershell -Command "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12;Invoke-WebRequest -Uri http://chocolatey.org/api/v2/package/ScriptCs -OutFile %ZIPFILE%"
powershell -Command "Add-Type -A System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory('%ZIPFILE%', '%EXDIR%')"
scriptcs -v
IF %ERRORLEVEL% NEQ 0 echo Failed to install scriptcs & goto end

:run
echo Installing ScriptCs.Octokit
scriptcs -i ScriptCs.Octokit

echo Running release notes generator script
scriptcs .\ReleaseNotesGenerator.csx -- "OctopusDeploy" "Library" "vNext" "Closed" %ISTEAMCITY%

:end
