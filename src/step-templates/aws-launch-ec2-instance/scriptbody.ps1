# Running outside octopus
param(
    [string]$odTags,
    [string]$odImageId,
    [string]$odInstanceType,
    [string]$odSubnetId,
    [string]$odSecurityGroupId,
    [string]$odKeyName,
    [string]$odRegion,
    [string]$odUserData,
    [decimal]$odSpotPrice,
    [string]$odSpotProduct,
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
            Throw "Missing parameter value $Name"
        }
    }

    return $result
}


function removeTags($instanceId, $tags)
{
    (ConvertFrom-StringData $tags).GetEnumerator() | Foreach-Object {
        try {
            Remove-EC2Tag -Tags @{key=$_.Key} -resourceId $instanceId -Force
        }
        catch [Amazon.EC2.AmazonEC2Exception] {
            Throw $_.Exception.errorcode + '-' + $_.Exception.Message
        }
    }
}

function NewTags($instanceId, $tags)
{
    (ConvertFrom-StringData $tags).GetEnumerator() | Foreach-Object {
        try {
            New-EC2Tag -Tags @{key=$_.Key;value=$_.Value} -resourceId $instanceId
        }
        catch [Amazon.EC2.AmazonEC2Exception] {
            Throw $_.Exception.errorcode + '-' + $_.Exception.Message
        }
    }
}


& {
    param(
        [string]$odTags,
        [string]$odImageId,
        [string]$odInstanceType,
        [string]$odSubnetId,
        [string]$odSecurityGroupId,
        [string]$odKeyName,
        [string]$odRegion,
        [string]$odUserData,
        [decimal]$odSpotPrice,
        [string]$odSpotProduct,
        [string]$odAccessKey,
        [string]$odSecretKey
    )

    # If AWS key's are not provided as params, attempt to retrieve them from Environment Variables
    if ($odAccessKey -or $odSecretKey) {
        Set-AWSCredentials -AccessKey $odAccessKey -SecretKey $odSecretKey -StoreAs default
    } elseif (([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -or ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine"))) {
        Set-AWSCredentials -AccessKey ([Environment]::GetEnvironmentVariable("AWS_ACCESS_KEY", "Machine")) -SecretKey ([Environment]::GetEnvironmentVariable("AWS_SECRET_KEY", "Machine")) -StoreAs default
    } else {
        Throw "AWS API credentials were not available/provided."
    }

    if ($odTags) {
        $filterArray = @()
        (ConvertFrom-StringData $odTags).GetEnumerator() | Foreach-Object {
            $filterHash = @{ Name="tag:"+$_.Key;value=$_.Value }
            $filterArray += $filterHash
        }

        $instanceObj = (Get-EC2Instance -Filter $filterArray | select -ExpandProperty Instances)
        $instanceCount = ($instanceObj | measure).Count
        $instanceId = $null
        $currentState = "missing"

        if ($instanceCount -gt 1) {
            Throw "More than one instance exists with the same tags - I don't know what to do!?"
        }
        elseif ($instanceCount -eq 1) {
            $instanceId = ($instanceObj).InstanceId
            $currentState = (Get-EC2Instance $instanceId).Instances.State.Name
            
            Write-Output ("------------------------------")
            Write-Output ("Checking the EC2 Instance status:")
            Write-Output ("------------------------------")

            $timeout = (New-Timespan -Seconds 90)
            $sw = [diagnostics.stopwatch]::StartNew()

            while ($true) {
                $currentState = (Get-EC2Instance $instanceId).Instances.State.Name

                if ($currentState -eq "running") {
                    break
                }
                elseif ($currentState -eq "terminated") {
                    (removeTags $instanceId $odTags) | out-null
                    $instanceId = $null
                    break
                }
                elseif ($currentState -eq "stopped") {
                    (Start-EC2Instance -InstanceIds $instanceId) | out-null
                }

                Write-Output ("$(Get-Date) | Waiting for Instance '$instanceId' to transition from state: $currentState")

                if ($sw.elapsed -gt $timeout) {Throw "Timed out waiting for desired state"}

                Sleep -Seconds 5
            }
            
            Write-Output ("$(Get-Date) | Instance state: $currentState")
        }
        
        # If the instance doesn't exist, create it!
        if ($instanceId -eq $null) {
            Write-Output ("------------------------------")
            Write-Output ("Creating a new EC2 instance:")
            Write-Output ("------------------------------")

            $encodedUserData = $null
            if ($odUserData -ne $null) { $encodedUserData = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes($odUserData) ) }

            if (!$odSpotPrice) {
                Write-Output ("$(Get-Date) | Attempting to create a new EC2 instance from ImageId: $odImageId")

                try {
                    $ec2Instances = (New-EC2Instance -ImageId $odImageId -KeyName $odKeyName -SecurityGroupId $odSecurityGroupId -InstanceType $odInstanceType -UserData $encodedUserData -SubnetId $odSubnetId -Region $odRegion)

                    $instanceId = $ec2Instances.Instances[0].InstanceId
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    Write-Output ($_.Exception.errorcode)
                    Write-Output ($_.Exception.Message)
                    Throw "Couldn't launch EC2 instance, sorry..."
                }
            }
            elseif ($odSpotPrice) {
                Write-Output ("$(Get-Date) | Attempting to create a new EC2 spot-instance from ImageId: $odImageId")

                try {
                    $spotInstancePricingObj = (Get-EC2SpotPriceHistory -InstanceType $odInstanceType -Region $odRegion -Filter @{ Name="product-description";value="$odSpotProduct" } -MaxResult 10)
                
                    Write-Output ("------------------------------")
                    Write-Output ("Listing the 10 most recent spot price changes for " + $odRegion + ":")
                    Write-Output ("------------------------------")

                    [decimal]$highPrice=0
                    $spotInstancePricingObj | Foreach-Object {
                        if ($highPrice -lt $_.Price) { $highPrice=$_.Price }
                        Write-Output ($_.AvailabilityZone + " | " + $_.InstanceType + " | " + $_.Price + " | " + $_.ProductDescription + " | " + $_.Timestamp)
                    }

                    if ($odSpotPrice -lt ($highPrice*1.1)) { Write-Output ("WARNING: Requested spot price (" + $odSpotPrice + ") may be too low: Below 10% of recent high (" + $highPrice + ")") }
                    if ($odSpotPrice -gt ($highPrice*5)) { Write-Output ("WARNING: Requested spot price (" + $odSpotPrice + ") may be too high: Over 5x recent high (" + $highPrice + ")") }
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    Write-Output ($_.Exception.errorcode)
                    Write-Output ($_.Exception.Message)
                    Throw "Couldn't gather spot pricing details, sorry..."
                }

                try {
                    $if0 = (New-Object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification)
                    $if0.DeviceIndex = 0
                    $if0.SubnetId = $odSubnetId
                    $if0.Groups.Add($odSecurityGroupId)

                    $spotInstanceRequestObj = (Request-EC2SpotInstance -SpotPrice $odSpotPrice -InstanceCount 1 -Type one-time -LaunchSpecification_ImageId $odImageId -LaunchSpecification_KeyName $odKeyName -LaunchSpecification_InstanceType $odInstanceType -LaunchSpecification_UserData $encodedUserData -Region $odRegion -LaunchSpecification_NetworkInterfaces $if0)
                
                    Write-Output ("------------------------------")
                    Write-Output ("Checking the spot request status:")
                    Write-Output ("------------------------------")

                    $timeout = (New-Timespan -Seconds 300)
                    $sw = [diagnostics.stopwatch]::StartNew()

                    while ($true)
                    {
                        if ($sw.elapsed -gt $timeout) { Throw "Timed out waiting for spot instance - please check manually!" }

                        $spotcurrentState = (Get-EC2SpotInstanceRequest -SpotInstanceRequestId ($spotInstanceRequestObj.SpotInstanceRequestId)).State
                        Write-Output ("$(Get-Date) | Current State: $spotcurrentState | Desired State: active")
                        if ($spotcurrentState -eq "active") { break }

                        Sleep -Seconds 5
                    }
                
                    Write-Output ("------------------------------")
                    Write-Output ("Spot Request details:")
                    Write-Output (Get-EC2SpotInstanceRequest -SpotInstanceRequestId ($spotInstanceRequestObj.SpotInstanceRequestId))
                    Write-Output ("------------------------------")

                    $instanceId = (Get-EC2SpotInstanceRequest -SpotInstanceRequestId ($spotInstanceRequestObj.SpotInstanceRequestId)).InstanceId
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    Write-Output ($_.Exception.errorcode)
                    Write-Output ($_.Exception.Message)
                    Throw "Couldn't launch spot instance"
                }
            }

            if ($odTags) { NewTags $instanceId $odTags }
        }

        if ($instanceId) {
            if ($currentState -ne "running") { 
                Write-Output ("------------------------------")
                Write-Output ("Checking the EC2 Instance status:")
                Write-Output ("------------------------------")

                Write-Output ("$(Get-Date) | Instance state: $currentState")

                $timeout = (New-Timespan -Seconds 90)
                $sw = [diagnostics.stopwatch]::StartNew()

                while ($true) {
                    $currentState = (Get-EC2Instance $instanceId).Instances.State.Name

                    if ($currentState -eq "running") { break }

                    Write-Output ("$(Get-Date) | Waiting for Instance '$instanceId' to transition from state: $currentState")

                    if ($sw.elapsed -gt $timeout) {Throw "Timed out waiting for desired state"}

                    Sleep -Seconds 5
                }

                Write-Output ("$(Get-Date) | Instance state: $currentState")
            }


            Write-Output ("------------------------------")
            Write-Output ("Instance details:")
            Write-Output ((Get-EC2Instance $instanceId).Instances)
            Write-Output ("------------------------------")
    
            $privateIpAddress = (Get-EC2Instance $instanceId).Instances.PrivateIpAddress
            $publicIpAddress = (Get-EC2Instance $instanceId).Instances.PublicIpAddress
            
            if($OctopusParameters) {
                Set-OctopusVariable -name "InstanceId" -value $instanceId
                Set-OctopusVariable -name "PrivateIpAddress" -value $privateIpAddress
                Set-OctopusVariable -name "PublicIpAddress" -value $publicIpAddress
            }
        }
    }
 } `
 (Get-Param 'odTags' -Required) `
 (Get-Param 'odImageId' -Required) `
 (Get-Param 'odInstanceType' -Required) `
 (Get-Param 'odSubnetId' -Required) `
 (Get-Param 'odSecurityGroupId' -Required) `
 (Get-Param 'odKeyName' -Required) `
 (Get-Param 'odRegion' -Required) `
 (Get-Param 'odUserData') `
 (Get-Param 'odSpotPrice') `
 (Get-Param 'odSpotProduct') `
 (Get-Param 'odAccessKey') `
 (Get-Param 'odSecretKey')