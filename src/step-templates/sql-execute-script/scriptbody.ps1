# Parameters
$ConnectionString = $OctopusParameters["ConnectionString"]
$ContinueOnError = $OctopusParameters["ContinueOnError"] -ieq "True"
$SqlQuery = $OctopusParameters["SqlScript"]
$CommandTimeout = $OctopusParameters["CommandTimeout"]
$CaptureOutputToVariables = $OctopusParameters["CaptureOutputToVariables"] -ieq "True"

# Local Variables
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $ConnectionString
$StepName = $OctopusParameters["Octopus.Step.Name"]

$global:outputs = @()

Register-ObjectEvent -InputObject $connection -EventName InfoMessage -Action {
    Write-Output $event.SourceEventArgs
} | Out-Null

function Execute-SqlQuery($SqlQuery) {
    $queries = [System.Text.RegularExpressions.Regex]::Split($SqlQuery, "^s*GOs*`$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)

    $queries | ForEach-Object {
        $query = $_
        if ((-not [String]::IsNullOrWhiteSpace($query)) -and ($query.Trim() -ine "GO")) {            
            $command = $connection.CreateCommand()
            $command.CommandText = $query
            $command.CommandTimeout = $CommandTimeout
            $command.ExecuteNonQuery() | Out-Null
        }
    }
}

$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { param($sender, $event) 
    $eventMessage = $event.Message
    Write-Verbose $eventMessage
    if ($CaptureOutputToVariables -eq $True) {
        $global:outputs += $eventMessage
    }
}

try {
	
    Write-Output "Attach InfoMessage event handler"
    $connection.add_InfoMessage($handler)
    
    Write-Output "Connecting"
    $connection.Open()

    Write-Output "Executing script"
    Execute-SqlQuery -SqlQuery $SqlQuery
}
catch {
    if ($ContinueOnError) {
        Write-Output "Error: $($_.Exception.Message)"
    }
    else {
        throw
    }
}
finally {
    if ($null -ne $connection) {
        Write-Output "Detach InfoMessage event handler"
        $connection.remove_InfoMessage($handler)
        Write-Output "Closing connection"
        $connection.Dispose()
    }
}

if ($CaptureOutputToVariables -eq $True) {
    Write-Output "Capture output to variables is true"
    Write-Output "Output Count: $($global:outputs.Length)"
    if ($global:outputs.Length -gt 0) {
        Write-Verbose "Setting Octopus output variables"
        for ($i = 0; $i -lt $global:outputs.Length; $i++) {
            $variableName = "SQLOutput-$($i+1)"
            $variableValue = $global:outputs[$i]
            Set-OctopusVariable -Name $variableName -Value $variableValue
            Write-Verbose "Created output variable: ##{Octopus.Action[$StepName].Output.$variableName}"
        }
    }
    else {
        Write-Verbose "No Octopus output variables to set"
    }
}