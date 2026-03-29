$xml = [xml](Get-Content "$PackagePath\$AppName.application")
$manifestpath = $xml.assembly.dependency.dependentAssembly.codebase
$ApplicationWithVersion = $manifestpath.Split('\\')[1]

$splittedParams = $AdvencedMageParameters.Split(" ")
& "$MagePath\mage.exe" -Update "$PackagePath\$manifestpath" -FromDirectory "$PackagePath\Application Files\$ApplicationWithVersion" $splittedParams