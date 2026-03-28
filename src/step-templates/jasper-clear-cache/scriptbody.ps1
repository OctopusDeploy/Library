# Name: ClearCache.ps1
# Author: Matt Smith
# Created Date: 28 July 2014
# Modified Date: 13 October 2014
# Version: 1.3

$servers = $OctopusParameters['fqdn'] -split ";"

foreach ($server in $servers)
{
    Write-Host 'Clearing cache in '$server
    $url = 'http://' + $server + '/' + $OctopusParameters['environment'] + '_web/report/meta'

    Function ClearCache($type)
    { 
      return Invoke-WebRequest -Uri $url/$type -Method GET -Headers @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($OctopusParameters['username']+":"+$OctopusParameters['password'] ))}
    }
  
    # Clear cache
    $reportresult = ClearCache -type 'reportcache?CLEAR=Clear+Cache'
    $templateresult =  ClearCache -type 'templatecache?CLEAR=Clear+Cache'
    $imageresult =  ClearCache -type 'imagescache?CLEAR=Clear+Cache'

}