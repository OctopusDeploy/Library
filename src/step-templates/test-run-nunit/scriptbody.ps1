Write-Output "Running NUnit tests..."

$exePath = '"' + $NUnitExePath + '"'
if (-not $exePath) {
    $exePath = "nunit-console.exe"
}

$runNUnit = "& $exePath /out:TestStdOut.txt /err:TestStdErr.txt $NUnitAdditionalArgs"

$NUnitTestAssemblies.Split(";") | ForEach {
    $asm = $_.Trim()
    Write-Output "Including assembly $asm"
    $runNUnit += " $asm"
}

cd $NUnitWorkingDirectoryPath

iex $runNUnit
$nunitExit = $lastExitCode

New-OctopusArtifact -Path TestResult.xml
New-OctopusArtifact -Path TestStdOut.txt
New-OctopusArtifact -Path TestStdErr.txt

exit $nunitExit
