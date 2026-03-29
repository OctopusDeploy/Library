$username = $OctopusParameters['username']
$pass = $OctopusParameters['pass']
$fileList = $OctopusParameters['fileList']

Try 
{
    foreach($file in $fileList.Split("`n")){
        "https://purge.mncdn.com/?username=$username&pass=$pass&file=$file"
        $result = Invoke-WebRequest -UseBasicParsing -Uri "https://purge.mncdn.com/?username=$username&pass=$pass&file=$file"
    }
}
catch [Exception] {
	"Error, couldn't finish purge operation. `r`n $_.Exception.ToString()"
}