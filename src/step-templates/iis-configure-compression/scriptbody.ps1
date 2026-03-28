$psPath = 'MACHINE/WEBROOT/APPHOST';

if ($StaticMimeTypes)
{
    $filter = "system.webServer/httpCompression/staticTypes";
    
    $existingStaticMimeTypes = (Get-WebConfigurationProperty -pspath $psPath -filter $filter -name ".").Collection;
    foreach ($staticMimeType in $StaticMimeTypes.split(","))
    {
        if ($staticMimeType)
        {
            if (($existingStaticMimeTypes | ? { $_.mimeType -eq $staticMimeType }).Count -ne 0)
            {
                Remove-WebConfigurationProperty -pspath $psPath -filter $filter -name "." -AtElement @{mimeType=$staticMimeType};
                Write-Output "Static MIME type $staticMimeType removed.";
            }
            
            Add-WebConfigurationProperty -pspath $psPath -filter $filter -name "." -value @{mimeType=$staticMimeType;enabled='True'};
            Write-Output "Static MIME type $staticMimeType added.";
        }
    }
}

if ($DynamicMimeTypes)
{
    $filter = "system.webServer/httpCompression/dynamicTypes";
    
    $existingDynamicMimeTypes = (Get-WebConfigurationProperty -pspath $psPath -filter $filter -name ".").Collection;
    foreach ($dynamicMimeType in $DynamicMimeTypes.split(","))
    {
        if ($dynamicMimeType)
        {
            if (($existingDynamicMimeTypes | ? { $_.mimeType -eq $dynamicMimeType }).Count -ne 0)
            {
                Remove-WebConfigurationProperty -pspath $psPath -filter $filter -name "." -AtElement @{mimeType=$dynamicMimeType};
                Write-Output "Dynamic MIME type $dynamicMimeType removed.";
            }
            
            Add-WebConfigurationProperty -pspath $psPath -filter $filter -name "." -value @{mimeType=$dynamicMimeType;enabled='True'};
            Write-Output "Dynamic MIME type $dynamicMimeType added.";
        }
    }
}