$cookBookFolder = $OctopusParameters["CookBookDir"]
$overrideRunList = $OctopusParameters["OverrideRunList"]

if (-not $cookBookFolder -or -not $overrideRunList) {
	throw "The parameters are mandatory."
}

$ClientPath = Join-Path $cookBookFolder "client.rb"
$WorkingPath = Join-Path $cookBookFolder "temp"
$DatabagPath = Join-Path $WorkingPath "data_bags"
$EnvironmentPath = Join-Path $WorkingPath "environments"
$CookbooksPath = Join-Path $WorkingPath "cookbooks"
$FileCachePath = Join-Path $WorkingPath "cache"

$ClientContent = @"
data_bag_path "$($DatabagPath -replace '\\','/')"
environment_path "$($EnvironmentPath -replace '\\','/')"
cookbook_path "$($CookbooksPath -replace '\\','/')"
file_cache_path "$($FileCachePath -replace '\\','/')"
ssl_verify_mode :verify_peer
"@

[System.IO.File]::WriteAllText($ClientPath, $ClientContent)

@($DatabagPath, $EnvironmentPath, $CookbooksPath, $FileCachePath) | %{
	if (!(Test-Path $_) ){ 
		mkdir -p $_
	}
}

Push-Location $cookBookFolder
Remove-Item *.lock
&berks vendor $CookbooksPath
&chef-client -z -c $ClientPath -o $overrideRunList
Pop-Location