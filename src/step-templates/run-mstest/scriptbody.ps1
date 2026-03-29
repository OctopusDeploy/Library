Write-Output "Running MsTests tests..."

$exePath = '"' + $MsTestExePath + '"'
if (-not $exePath) {
    $exePath = "mstest.exe"
}

$runMsTest = "& $exePath "

$MsTestAssemblies.Split(";") | ForEach {
    $asm = " /testcontainer:"+$_.Trim()
    Write-Output "Including test container assembly $asm"
    $runMsTest += "$asm"
}
Write-Host $runMsTest
cd $MsTestWorkingDirectoryPath
Write-Host $MsTestWorkingDirectoryPath  

iex $runMsTest
$mstestExit = $lastExitCode


exit $mstestExit