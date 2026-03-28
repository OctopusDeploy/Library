Write-Verbose "Downloading file $FileUrl, to the destination $FilePath" -Verbose
$client = new-object System.Net.WebClient
$client.DownloadFile($FileUrl, $FilePath)
Write-Verbose "File downloadded" -Verbose
