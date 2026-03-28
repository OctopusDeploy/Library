$seconds = $OctopusParameters['Seconds']
$forceCloseOnTimeout = $OctopusParameters['Force']
$processName = $OctopusParameters['ProcessName']
$timeout = new-timespan -Seconds $seconds
$stopwatch = [diagnostics.stopwatch]::StartNew()

# Check if the process is even running
if (Get-Process $processName -ErrorAction silentlycontinue)
{
    Write-Host "Waiting $seconds seconds for process '$processName' to terminate"
} 
else 
{
    Write-Host "Process '$processName' is not running"
    return
}

# Count down waiting for the process to stop gracefully
while ($stopwatch.elapsed -lt $timeout)
{
    # Check process is running
    if (Get-Process $processName -ErrorAction silentlycontinue) 
    {
        Write-Host "Waiting..."
    }
    else 
    {
        Write-Host "Process '$processName' is no longer running"
        return
    }

    # Wait for a while
    Start-Sleep -seconds 1
}

# Force close the process if set
if($forceCloseOnTimeout –eq $TRUE)
{
    Write-Host "Force closing process $processName"
    Stop-Process -processname $processName -Force
    Write-Host "Process '$processName' is no longer running"
    return
}

Write-Host "Process $processName didn't close within the allocated time"
Write-Host "Continuing anyway"