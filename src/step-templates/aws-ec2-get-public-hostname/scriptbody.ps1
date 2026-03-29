$downloader = new-object System.Net.WebClient
$hostname = $downloader.DownloadString("http://instance-data/latest/meta-data/public-hostname")
Set-OctopusVariable -name "Hostname" -value $hostname
