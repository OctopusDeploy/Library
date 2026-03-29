
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xml.XmlDocument");
[void][System.Reflection.Assembly]::LoadWithPartialName("System.IO");
 
$reportServerName = $reportServer;
$ReportServiceWebServiceURL = "http://$reportServerName/ReportServer/"
$ssrsVersion = $version;
$exportFolder = $folder;


if ($ssrsVersion -gt 2005) 
	{
		# SSRS 2008/2012
		$reportServerUri = "$ReportServiceWebServiceURL/ReportService2010.asmx" -f $reportServerName
	} else {
		# SSRS 2005
		$reportServerUri = "$ReportServiceWebServiceURL/ReportService2005.asmx" -f $reportServerName
	}


$Proxy = New-WebServiceProxy -Uri $reportServerUri -Namespace SSRS.ReportingService2005 -UseDefaultCredential ;


if ($ssrsVersion -gt 2005) {		 
		$items = $Proxy.ListChildren("/", $true) | `
				 Select-Object TypeName, Path, ID, Name | `
				 Where-Object {$_.typeName -eq "Report"};
	} else {
		$items = $Proxy.ListChildren("/", $true) | `
             Select-Object Type, Path, ID, Name | `
             Where-Object {$_.type -eq "Report"};
	}


$folderName = $exportFolder + "\" + (Get-Date -format "yyyy-MM-dd-hhmmtt");

 
foreach($item in $items)
{

    $subfolderName = split-path $item.Path;
    $reportName = split-path $item.Path -Leaf;
    $fullSubfolderName = $folderName + $fullFolderName + $subfolderName;
    if(-not(Test-Path $fullSubfolderName))
    {

        [System.IO.Directory]::CreateDirectory($fullSubfolderName) | out-null
    }
 
    $rdlFile = New-Object System.Xml.XmlDocument;
    [byte[]] $reportDefinition = $null;
    
    if ($ssrsVersion -gt 2005) {
			$reportDefinition = $Proxy.GetItemDefinition($item.Path);
		} else {
			$reportDefinition = $Proxy.GetReportDefinition($item.Path);
		}
    
    [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(,$reportDefinition));
    $rdlFile.Load($memStream);
 
    $fullReportFileName = $fullSubfolderName + "\" + $item.Name +  ".rdl";
    
    Write-Output $fullReportFileName;
    
    $rdlFile.Save($fullReportFileName);
    
 
}