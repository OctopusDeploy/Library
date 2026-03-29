[int]$Wait = $Seconds
Write-Output "Waiting for $seconds seconds"
for ($CountDown = $Wait; $CountDown -ge 0; $CountDown--){
Write-Verbose "$CountDown seconds remaining"
Start-Sleep 1
}