# Running outside octopus
param(
    [string]$odGroupName,
    [string]$odGroupDescription,
    [string]$odVpcId,
    [string]$odRules,
    [string]$odInstanceId,
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
        [string]$odGroupName,
        [string]$odGroupDescription,
        [string]$odVpcId,
        [string]$odRules,
        [string]$odInstanceId,
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



    Write-Output ("------------------------------")
    Write-Output ("Checking the Security Group:")
    Write-Output ("------------------------------")
    
    $filterArray = @()
    $filterArray += @{ name="vpc-id";value=$odVpcId }
    $filterArray += @{ name="group-name";value=$odGroupName }
    $filterArray += @{ name="description";value=$odGroupDescription }

    $securityGroupObj = (Get-EC2SecurityGroup -Filter $filterArray)
    $securityGroupCount = ($securityGroupObj | measure).Count
    $securityGroupId = $null

    if ($securityGroupCount -gt 1) {
        throw "More than one security group exists with the same vpcid/name/description - I don't know what to do!?"
    }
    elseif ($securityGroupCount -eq 1) {
        Write-Output ("$(Get-Date) | Security group already exists...")

        $securityGroupId = ($securityGroupObj).GroupId
    }
    elseif ($securityGroupCount -eq 0) {
        Write-Output ("$(Get-Date) | Creating security group...")

        $securityGroupId = (New-EC2SecurityGroup -VpcId $odVpcId -GroupName $odGroupName -GroupDescription $odGroupDescription)

        Write-Output ("Security Group Created: $($securityGroupId)")
    }

    if ($securityGroupId -and $OctopusParameters) {
        Set-OctopusVariable -name "GroupId" -value $securityGroupId
    }

    if ($odRules) {
        (ConvertFrom-StringData $odRules).GetEnumerator() | Foreach-Object {
            $ruleSplit = $_.Value.Split("|")
        
            $direction = $ruleSplit[0]
            $ipProtocol = $ruleSplit[1]
            $fromPort = $ruleSplit[2]
            $toPort = $ruleSplit[3]
            $ipRanges = $ruleSplit[4]

            Write-Output ("------------------------------")
            Write-Output ("Creating new $($direction) rule for Security Group $($securityGroupId):")
            Write-Output ("------------------------------")

            $failCount = 0
            while ($true) {
                try {
                    if ($direction -eq "Ingress") {
                        $check_ipPermissionObj = ($securityGroupObj | Select -ExpandProperty IpPermissions | ? {$_.IpProtocol -eq $ipProtocol -and $_.FromPort -eq $fromPort -and $_.ToPort -eq $toPort})
                    }
                    elseif ($direction -eq "Egress") {
                        $check_ipPermissionObj = ($securityGroupObj | Select -ExpandProperty IpPermissionsEgress | ? {$_.IpProtocol -eq $ipProtocol -and $_.FromPort -eq $fromPort -and $_.ToPort -eq $toPort})
                    }

                    break
                } 
                catch {
                    $failCount++
                }

                if ($failCount -eq 3) { throw "Could not register the task after three attempts!" }
            }



            $check_ipRangesObj = ($check_ipPermissionObj | Select -ExpandProperty IpRanges | ? {$_ -eq $ipRanges})
            $check_ipRangesObjCount = ($check_ipRangesObj | measure).Count

            if ($check_ipRangesObjCount -gt 0) {
                Write-Output ("$(Get-Date) | Rule '$($_.Key)' already exists...")
            }
            else {
                Write-Output ("$(Get-Date) | Creating new rule '$($_.Key)'...")
                
                $ipPermissionObj = (New-Object "Amazon.EC2.Model.IpPermission")
                $ipPermissionObj.IpProtocol = $ipProtocol
                $ipPermissionObj.FromPort = $fromPort
                $ipPermissionObj.ToPort = $toPort
                

                try {
                    $ipRangesObj = (New-Object "Amazon.EC2.Model.IpRange")
                    $ipRangesObj.CidrIp = $ipRanges
                    $ipRangesObj.Description = $_.Key
                    $ipPermissionObj.Ipv4Ranges = $ipRangesObj
                }
                catch {
                    Write-Output ("$(Get-Date) | Cannot create 'Amazon.EC2.Model.IpRange' object, possibly running an old version of the 'AWS Tools for Windows PowerShell'")
                    Write-Output ("$(Get-Date) | Attempting to use the old method, but the old method does not allow rule comments/descriptions")

                    $ipRangesObj = (New-Object "System.Collections.Generic.List[string]")
                    $ipRangesObj.Add($ipRanges)
                    $ipPermissionObj.IpRanges = $ipRangesObj
                }

                Write-Output $ipPermissionObj

                try {
                    if ($direction -eq "Ingress") {
                        Grant-EC2SecurityGroupIngress -GroupId $securityGroupId -IpPermission $ipPermissionObj
                    }
                    elseif ($direction -eq "Egress") {
                        Grant-EC2SecurityGroupEgress -GroupId $securityGroupId -IpPermission $ipPermissionObj
                    }
                }
                catch [Amazon.EC2.AmazonEC2Exception] {
                    throw $_.Exception.errorcode + '-' + $_.Exception.Message
                }

                Write-Output ("------------------------------")
                Write-Output ("New $($direction) ruleset looks like:")
                Write-Output ("------------------------------")

                $securityGroupObj = (Get-EC2SecurityGroup -Filter $filterArray)

                if ($direction -eq "Ingress") {
                    Write-Output $securityGroupObj | Select -ExpandProperty IpPermissions | ? {$_.IpProtocol -eq $ipProtocol -and $_.FromPort -eq $fromPort -and $_.ToPort -eq $toPort}
                }
                elseif ($direction -eq "Egress") {
                    Write-Output $securityGroupObj | Select -ExpandProperty IpPermissionsEgress | ? {$_.IpProtocol -eq $ipProtocol -and $_.FromPort -eq $fromPort -and $_.ToPort -eq $toPort}
                }
            }
        }
    }




    if ($odInstanceId) {
        $filterArray = @()
        $filterArray += @{ name="instance-id";value=$odInstanceId }

        $instanceObj = (Get-EC2Instance -Filter $filterArray | select -ExpandProperty Instances)
        $instanceCount = ($instanceObj | measure).Count

        if ($instanceCount -gt 1) {
            throw "More than one instance exists with the same instance id - I don't know what to do!?"
        }
        elseif ($instanceCount -eq 1) {
            Write-Output ("$(Get-Date) | Found instance '$($odInstanceId)'!")
 
            $securityGroupArray = @()
            $securityGroupArray += ($instanceObj.NetworkInterfaces | Where-Object {$(Get-EC2NetworkInterface -NetworkInterfaceId $($_.NetworkInterfaceId))} | Select -ExpandProperty Groups | Select GroupId | Select -Expand GroupId)

            if ($securityGroupArray -contains $securityGroupId) {
                Write-Output ("$(Get-Date) | Security Group '$($securityGroupId)' is already associated with the Instance '$($odInstanceId)'...")
            }
            else {
                Write-Output ("$(Get-Date) | Adding Security Group '$($securityGroupId)' to the Instance '$($odInstanceId)'!")

                $securityGroupArray += $securityGroupId
                $instanceObj.NetworkInterfaces | Where-Object {$(Edit-EC2NetworkInterfaceAttribute -NetworkInterfaceId $($_.NetworkInterfaceId) -Groups $securityGroupArray)}
            }
        }

        Write-Output ("------------------------------")
        Write-Output ("Security Groups for instance '$($odInstanceId)':")
        Write-Output ("------------------------------")
        
        $instanceObj = (Get-EC2Instance -Filter $filterArray | select -ExpandProperty Instances)
        Write-Output $instanceObj.NetworkInterfaces | Where-Object {$(Get-EC2NetworkInterface -NetworkInterfaceId $($_.NetworkInterfaceId))} | Select -ExpandProperty Groups
    }
 } `
 (Get-Param 'odGroupName' -Required) `
 (Get-Param 'odGroupDescription' -Required) `
 (Get-Param 'odVpcId' -Required) `
 (Get-Param 'odRules') `
 (Get-Param 'odInstanceId') `
 (Get-Param 'odAccessKey') `
 (Get-Param 'odSecretKey')