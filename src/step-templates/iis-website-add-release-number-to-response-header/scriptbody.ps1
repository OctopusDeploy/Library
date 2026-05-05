Write-Host "Adding release number to response header"

function Get-IISServerManager
{
    [CmdletBinding()]
    [OutputType([System.Object])]
    param ()

    $iisInstallPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\INetStp' -Name InstallPath).InstallPath
    if (-not $iisInstallPath)
    {
        throw ('IIS installation path not found')
    }
    $assyPath = Join-Path -Path $iisInstallPath -ChildPath 'Microsoft.Web.Administration.dll' -Resolve -ErrorAction:SilentlyContinue
    if (-not $assyPath)
    {
        throw 'IIS version of Microsoft.Web.Administration.dll not found'
    }
    $assy = [System.Reflection.Assembly]::LoadFrom($assyPath)
    return [System.Activator]::CreateInstance($assy.FullName, 'Microsoft.Web.Administration.ServerManager').Unwrap()
}

$iis = Get-IISServerManager
$config = $iis.GetWebConfiguration($OctopusParameters['headerWebsiteName'])
$httpProtocolSection = $config.GetSection("system.webServer/httpProtocol")
$customHeadersCollection = $httpProtocolSection.GetCollection("customHeaders")

$update = $true

foreach($path in $customHeadersCollection.GetCollection()) { 
    if ($path.GetAttributeValue("name") -eq $OctopusParameters['headerFieldName']) {
        write-host "Release number is already in the response header, skipping"
        $update = $false
        break
    }
}

if ($update)
{
    $fieldName = $OctopusParameters['headerFieldName']
    $releaseNumber = $OctopusParameters['Octopus.Release.Number']
    
    Write-Host "Adding release number $releaseNumber to custom header $fieldName"
    
    $addElement = $customHeadersCollection.CreateElement("add")
    $addElement["name"] = $fieldName
    $addElement["value"] = $releaseNumber
    $customHeadersCollection.Add($addElement)
    
    $iis.CommitChanges() | Write-Host
}