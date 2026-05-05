$filePath = $OctopusParameters['FilePath']
$fileContent = $OctopusParameters['FileContent']
$encoding = $OctopusParameters['Encoding']

New-Item -ItemType file -Path $filePath -Value '' -force

if(![string]::IsNullOrEmpty($fileContent))
{
  Set-Content -path $filePath -value $fileContent -encoding $encoding
}