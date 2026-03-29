$find = Get-ChildItem "$PackagePath\$SignFileFilter"
$PathToFile = $find.FullName

$splittedParams = $AdvencedMageParameters.Split(" ")
& "$MagePath\mage.exe" -Sign "$PathToFile" -CertFile $SignCert -Password $SignCertPass $splittedParams