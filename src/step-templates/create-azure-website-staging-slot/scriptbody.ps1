# Check if Windows Azure Powershell is avaiable 
try{ 
    Import-Module Azure -ErrorAction Stop
}catch{
    throw "Windows Azure Powershell not found! Please make sure to install them from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
}


$stagingWebsite = Get-AzureWebsite -Name $AzureWebSite -Slot staging -ErrorAction SilentlyContinue


if($stagingWebsite -eq $null)
{
    Write-Host "Creating staging slot"
    $stagingWebsite = New-AzureWebsite -Name $AzureWebSite -Slot staging -Location $Location
}


Set-OctopusVariable -name "AzurePassword" -value $stagingWebsite.PublishingPassword
Set-OctopusVariable -name "AzureUsername" -value $stagingWebsite.PublishingUsername

$urlString = ($stagingWebsite.SiteProperties.Properties | ?{ $_.Name -eq "RepositoryURI" }).Value.ToString()
$url = [System.Uri]$urlString


Set-OctopusVariable -Name "AzurePublishUrl" -value $url.Host