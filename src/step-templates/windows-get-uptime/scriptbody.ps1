$pc = $computer
$info = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computer
$diff = ($info.ConvertToDateTime($info.LocalDateTime) - $info.ConvertToDateTime($info.LastBootUpTime))
 
$properties=[ordered]@{
 'ComputerName'=$pc;
 'UptimeDays'=$diff.Days;
 'UptimeHours'=$diff.Hours;
 'UptimeMinutes'=$diff.Minutes
 'UptimeSeconds'=$diff.Seconds
 }
 $obj = New-Object -TypeName PSObject -Property $properties
 
Write-Output $obj