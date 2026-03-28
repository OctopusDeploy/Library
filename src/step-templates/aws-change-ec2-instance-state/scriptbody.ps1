# Running outside octopus
param(
    [string]$odInstanceId,
    [string]$odState,
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


& {
    param(
        [string]$odInstanceId,
        [string]$odState,
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

    if ($odInstanceId) {
        $instanceObj = (Get-EC2Instance $odInstanceId | select -ExpandProperty Instances)
        $instanceCount = ($instanceObj | measure).Count

        if ($instanceCount -eq 1) {
            $instanceId = ($instanceObj).InstanceId
            
            Write-Output ("------------------------------")
            Write-Output ("Checking/Setting the EC2 Instance state:")
            Write-Output ("------------------------------")
            
            $currentState = (Get-EC2Instance $instanceId).Instances.State.Name

            if ($odState -eq "running" -and $currentState -ne "running") {
                $changeInstanceStateObj = (Start-EC2Instance -InstanceId $instanceId)
            }
            elseif ($odState -eq "absent" -and $currentState -ne "terminated") {
                $changeInstanceStateObj = (Remove-EC2Instance -InstanceId $instanceId -Force)
            }
            elseif ($odState -eq "stopped" -and $currentState -ne "stopped") {
                $changeInstanceStateObj = (Stop-EC2Instance -InstanceId $instanceId)
            }

            $timeout = new-timespan -Seconds 120
            $sw = [diagnostics.stopwatch]::StartNew()

            while ($true) {
                $currentState = (Get-EC2Instance $instanceId).Instances.State.Name

                if ($currentState -eq "running" -and $odState -eq "running") {
                    break
                }
                elseif ($currentState -eq "terminated" -and $odState -eq "absent") {
                    break
                }
                elseif ($currentState -eq "stopped" -and $odState -eq "stopped") {
                    break
                }

                Write-Output ("$(Get-Date) | Waiting for Instance '$instanceId' to transition from state: $currentState")

                if ($sw.elapsed -gt $timeout) { throw "Timed out waiting for desired state" }

                Sleep -Seconds 5
            }
 
            Write-Output ("------------------------------")
            Write-Output ("$(Get-Date) | $($instanceId) state: $currentState")
            Write-Output ("------------------------------")
        }
        else
        {
            Write-Output ("Instance '$instanceId' could not be found...?")
        }
    }
 } `
 (Get-Param 'odInstanceId' -Required) `
 (Get-Param 'odState' -Required) `
 (Get-Param 'odAccessKey') `
 (Get-Param 'odSecretKey')