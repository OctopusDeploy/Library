param(
    [string]$ConnectionString,
    [string]$JobId,
    [string]$JobName,
    [string]$JobStatus
)

$ErrorActionPreference = "Stop"

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

function Execute-SqlQuery($query) {
    $queries = [System.Text.RegularExpressions.Regex]::Split($query, "^\s*GO\s*$$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline)

    $queries | ForEach-Object {
        $q = $_
        if (!(StringIsNullOrWhitespace($q)) -and ($q.Trim().ToLowerInvariant() -ne "go")) {
            $command = $connection.CreateCommand()
            $command.CommandText = $q
            $command.ExecuteNonQuery() | Out-Null
        }
    }
}

& {
    param(
        [string]$ConnectionString,
        [string]$JobId,
        [string]$JobName,
        [string]$JobStatus
    )

    $jobStatusText = ''
    if ($JobStatus -eq '1') {
        $jobStatusText = "Enabling"
    } elseif ($JobStatus -eq '0') {
        $jobStatusText = "Disabling"
    }

    $jobDisplayName = ''
    if ($JobName) {
        $jobDisplayName = $JobName
    } else {
    	$jobDisplayName = $JobId
    }

    Write-Highlight "$jobStatusText SQL Server job: [$jobDisplayName]"
    Write-Verbose "SQL Server Job Id: [$JobId]"

    $query = @"
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_id=N'$JobId', @enabled=$JobStatus
GO
"@

	$connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $ConnectionString
    Register-ObjectEvent -inputobject $connection -eventname InfoMessage -action {
        write-host $event.SourceEventArgs
    } | Out-Null

    Write-Verbose "Connecting"
    try {
        $connection.Open()

        Write-Verbose "Executing script"
        Write-Verbose $query
        Execute-SqlQuery -query $query
    }
    catch [Exception]
    {
        Write-Verbose $_.Exception|format-list -force
        throw $_
    }
    finally {
        Write-Verbose "Closing connection"
        $connection.Dispose()
    }

  } `
   (Get-Param 'ConnectionString' -Required) `
   (Get-Param 'JobId' -Required) `
   (Get-Param 'JobName') `
   (Get-Param 'JobStatus' -Required)