# Running outside octopus
param(
    [string]$odZoneId,
    [string]$odAction,
    [string]$odName,
    [string]$odResourceAddress,
    [string]$odType,
    [string]$odTtl,
    [string]$odWait,
    [string]$odComment,
    [string]$odAccessKey,
    [string]$odSecretKey,
    [switch]$whatIf
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

    if (!$result -or $result -eq $null) {
        if ($Default) {
            $result = $Default
        } elseif ($Required) {
            throw "Missing parameter value $Name"
        }
    }

    return $result
}

# More custom functions would go here

& {
    param(
        [string]$odZoneId,
        [string]$odAction,
        [string]$odName,
        [string]$odResourceAddress,
        [string]$odType,
        [string]$odTtl,
        [string]$odWait,
        [string]$odComment,
        [string]$odAccessKey,
        [string]$odSecretKey
    )
    
    # If AWS key's are not provided as params, attempt to retrieve them from Environment Variables
    if ($odAccessKey -or $odSecretKey) {
        Set-AWSCredentials -AccessKey $odAccessKey -SecretKey $odSecretKey -StoreAs default
    } elseif (([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -or ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine"))) {
        Set-AWSCredentials -AccessKey ([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -SecretKey ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine")) -StoreAs default
    } else {
        throw "AWS API credentials were not available/provided."
    }

    If($odAction -ne "CREATE" -and $odAction -ne "DELETE" -and $odAction -ne "UPSERT") { throw "Invalid Action provided. Please use CREATE, DELETE or UPSERT." }

    if ($odName -notmatch '.+?\.$') { $odName += '.' }

    $change = (New-Object Amazon.Route53.Model.Change)
    $change.Action = $odAction
    $change.ResourceRecordSet = (New-Object Amazon.Route53.Model.ResourceRecordSet)
    $change.ResourceRecordSet.Name = $odName
    $change.ResourceRecordSet.Type = $odType
    $change.ResourceRecordSet.TTL = $odTtl
    
    if ($odResourceAddress -like '*,*') {
        $($odResourceAddress -split ',') | Foreach-Object {
            $change.ResourceRecordSet.ResourceRecords.Add(@{Value=$($_)})
        }
    } else {
        $change.ResourceRecordSet.ResourceRecords.Add(@{Value=$odResourceAddress})
    }

    Write-Output ("------------------------------")
    Write-Output ("Checking if Resource Record Set Exists:")
    Write-Output ("------------------------------")

    $resourceRecordSetObj = $(Get-R53ResourceRecordSet -HostedZoneId $odZoneId).ResourceRecordSets | Where {$_.Name -eq $odName}
    $resourceRecordSetCount = ($resourceRecordSetObj | measure).Count

    if ($odAction -eq "DELETE") {
        if ($resourceRecordSetCount -gt 0) {
            Write-Output ("The record '$($odName)' exists, deleting...")
        } else {
            Write-Output ("Cannot Delete: The record '$($odName)' does not exist, skipping...")
            Exit
        }
    } elseif ($odAction -eq "CREATE") {
        if ($resourceRecordSetCount -gt 0) {
            Write-Output ("Cannot Create: The record '$($odName)' already exists, skipping...")
            Exit
        } else {
            Write-Output ("The record '$($odName)' does not exist, creating record...")
        }
    } elseif ($odAction -eq "UPSERT") {
        if ($resourceRecordSetCount -gt 0) {
            Write-Output ("The record '$($odName)' already exists, updating record...")
        } else {
            Write-Output ("The record '$($odName)' does not exist, creating record...")
        }
    } else { throw "OMG - Unexpected result" }
    
    $params = @{
        HostedZoneId=$odZoneId
        ChangeBatch_Comment=$odComment
        ChangeBatch_Change=$change
    }

    Write-Output ("------------------------------")
    Write-Output ("Listing DNS change/s to be made:")
    Write-Output ("------------------------------")

    $($params.ChangeBatch_Change) | Foreach-Object {
        $resourceRecords=" | "

        $($_.ResourceRecordSet.ResourceRecords) | Foreach-Object {
            $resourceRecords += $_.Value + ","
        }

        Write-Output ($($_.Action.Value) + " | " + $($_.ResourceRecordSet.Name) + " | " + $($_.ResourceRecordSet.Type) + $($resourceRecords -replace ".$"))
    }

    

    $timeout = new-timespan -Seconds 30
    $sw = [diagnostics.stopwatch]::StartNew()
    $attempt = 1

    while ($true) {
        try {
            $result = Edit-R53ResourceRecordSet @params
            break
        }
        catch [Amazon.Route53.AmazonRoute53Exception] {
            Write-Output ("$($_.Exception.errorcode)-$($_.Exception.Message)")

            if ($attempt -eq 3) {
                throw $_.Exception.errorcode + '-' + $_.Exception.Message
            }

            if ($sw.elapsed -gt $timeout) {throw "Timed out waiting for 'Edit-R53ResourceRecordSet' to succeed"}

            Write-Output ("Attempt no.$($attempt) failed - Trying again in 5 seconds...")
            Sleep -Seconds 5

            $attempt++
        }
    }


    Write-Output ("------------------------------")
    Write-Output ("Checking the R53 Change status:")
    Write-Output ("------------------------------")

    $timeout = new-timespan -Seconds 120
    $sw = [diagnostics.stopwatch]::StartNew()

    while ($true) {
        $currentState = (Get-R53Change -Id $result.Id).Status

        if ($currentState -eq "INSYNC") {break}
        if ([bool]($odWait -eq $false)) {break}

        Write-Output ("$(Get-Date) | Waiting for R53 Change '$($result.Id)' to transition from state: $currentState")

        if ($sw.elapsed -gt $timeout) {throw "Timed out waiting for desired state"}

        Sleep -Seconds 5
    }
    Write-Output ("$(Get-Date) | R53 Change state: $currentState")
 } `
 (Get-Param 'odZoneId' -Required) `
 (Get-Param 'odAction' -Required) `
 (Get-Param 'odName' -Required) `
 (Get-Param 'odResourceAddress' -Required) `
 (Get-Param 'odType' -Required) `
 (Get-Param 'odTtl' -Required) `
 (Get-Param 'odWait' -Required) `
 (Get-Param 'odComment') `
 (Get-Param 'odAccessKey') `
 (Get-Param 'odSecretKey')