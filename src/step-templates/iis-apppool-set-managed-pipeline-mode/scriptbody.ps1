$AppPoolName = $OctopusParameters["AppPoolName"]
$Mode = $OctopusParameters["PiplelineMode"]

Import-Module WebAdministration

Get-ChildItem IIS:\AppPools | ?{$_.Name -eq $AppPoolName} | Select-Object -ExpandProperty PSPath | %{ Set-ItemProperty $_ managedPipelineMode $Mode -Verbose}