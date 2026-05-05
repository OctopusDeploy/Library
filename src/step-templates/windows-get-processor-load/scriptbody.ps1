$prcInfo = gwmi win32_processor -computer $ComputerName -ErrorAction STOP
Try{
    $Name = "Proc type: $($prcInfo.Name)"
    $Load = "Proc load: $($prcInfo.LoadPercentage) %"
    $Freq = "Proc frequency: $($prcInfo.CurrentClockSpeed) MHz"
    "$Name `n$Load `n$Freq"
}
Catch
{
    Write-Host "Error getting processor load information."
}