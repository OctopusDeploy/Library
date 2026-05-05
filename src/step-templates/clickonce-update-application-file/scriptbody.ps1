$xml = [xml](Get-Content "$PackagePath\$AppName.application")
$manifestpath = $xml.assembly.dependency.dependentAssembly.codebase

$splittedParams = $AdvencedMageParameters.Split(" ")
cd "$PackagePath"
& "$MagePath\mage.exe" -Update ".\$AppName.application" -AppManifest ".\$manifestpath" $splittedParams

