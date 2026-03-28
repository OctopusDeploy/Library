#region Verify variables

#Verify RunCondition can be converted to boolean.
$runCondition = $false
If ([string]::IsNullOrEmpty($OctopusParameters['RunCondition'])){
    Throw "Run Condition cannot be null."
}
Else{
    Try{
        $runCondition = [System.Convert]::ToBoolean($OctopusParameters['RunCondition'])
        Write-Host ("Run Condition: '" + $OctopusParameters['RunCondition'] + "' converts to boolean: " + $runCondition + ".")

        #If run condition evaluates to false, just return/stop processing.
        If (!$runCondition){
            Write-Host "Skipping step."
            return
        }
    }
    Catch{
        Throw "Cannot convert Run Condition: '" + $OctopusParameters['RunCondition'] + "' to boolean value."
    }
}

#No need to verify WaitForConnections as this is a checkbox and will always have a boolean value. Report value back for logging.
Write-Host ("Wait for connections to drop to 0: " + $OctopusParameters['WaitForConnections'])

#Verify MaxWaitTime can be converted to integer.
If ([string]::IsNullOrEmpty($OctopusParameters['MaxWaitTime'])){
    Throw "Maximum wait time in seconds cannot be null."
}

[int]$maxWaitTime = 0
[bool]$result = [int]::TryParse($OctopusParameters['MaxWaitTime'], [ref]$maxWaitTime )

If ($result){
    Write-Host ("Maximum wait time in seconds: " + $maxWaitTime)
}
Else{
    Throw "Cannot convert Maximum wait time in seconds: '" + $OctopusParameters['MaxWaitTime'] + "' to integer."
}

#No need to verify LtmStatus as this is a drop down box and will always have a value. Report back for logging.
Write-Host ("LTM Status: " + $OctopusParameters['LtmStatus'])

<#
Verify List of LTM info.
LTM Info should contain a list of all Pools, IPs, and Ports. Each set should be delmited by carriage returns, each valude delimited by pipe (|).
Here is an example:
Pool_192.168.103.226_443|192.168.103.174|443 
Pool_192.168.103.226_80|192.168.103.174|80
#>
If ([string]::IsNullOrEmpty($OctopusParameters['LtmInfo'])){
    Throw "List of LTM info cannot be null."
}
#Write out LTM info. If the project is using variables (and it most likely is), it may be difficult to debug without seeing what it evaluated to.
Write-Host ("List of LTM info: " + [Environment]::NewLine + $OctopusParameters['LtmInfo'])
$f5Pools = ($OctopusParameters['LtmInfo']).Split([Environment]::NewLine)
Foreach ($f5Pool in $f5Pools){
    #Validate 3 values are passed in per line.
    $poolInfo = $f5Pool.Split("|")
    If ($poolInfo.Count -ne 3){
        Throw ("Invalid pool info. Expecting 'PoolName|IpAddress|Port': '" + $f5Pool + "'.")
    }
    
    #Validate that each value is not null.
    Foreach ($f5Parm in $poolInfo){
        If ([string]::IsNullOrEmpty($f5Parm)){
            Throw ("Invalid pool info. Expecting 'PoolName|IpAddress|Port': '" + $f5Pool + "'. None can be empty.")
        }
    }
    
    #Validate IP Address (second value).
    If ( !($poolInfo[1] -as [ipaddress]) ){
        Throw ("Invalid IP Address: '" + $poolInfo[1] + "'.")
    }

    #Validate Port (third value).
    [int]$port = 0
    [bool]$result = [int]::TryParse($poolInfo[2], [ref]$port )
    
    If ( !($result) ){
        Throw ("Invalid port (expecting integer): '" + $poolInfo[2] + "'.")
    }
}

#Verify HostName is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['HostName'])){
    Throw "LTM Host name cannot be null."
}
Write-Host ("LTM Host: " + $OctopusParameters['HostName'])

#Verify Username is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['Username'])){
    Throw "LTM username cannot be null."
}
Write-Host ("Username: " + $OctopusParameters['Username'])

#Verify Password is not null.
If ([string]::IsNullOrEmpty($OctopusParameters['Password'])){
    Throw "LTM password cannot be null."
}

#Verify ConnectionCount can be converted to integer.
If ([string]::IsNullOrEmpty($OctopusParameters['ConnectionCount'])){
    Throw "Kill connections when less than or equal to cannot be null."
}

[int]$killConnectionWhenLE = 0
[bool]$result = [int]::TryParse($OctopusParameters['ConnectionCount'], [ref]$killConnectionWhenLE )

If ($result){
    Write-Host ("Kill connections when less than or equal to: " + $killConnectionWhenLE)
}
Else{
    Throw "Cannot convert Kill connections when less than or equal to: '" + $OctopusParameters['ConnectionCount'] + "' to integer."
}

#endregion

#region Functions

Function Set-F5PoolState{
    param(
        $f5Pools,
        [switch]$forceOffline
    )
    
    Foreach ($f5Pool in $f5Pools){
        $poolInfo = $f5Pool.Split("|")
        
        $poolName = $poolInfo[0]
        $ipAddress = $poolInfo[1]
        $port = $poolInfo[2]
        
        $member = ($ipAddress + ":" + $port)
        
        $state = $OctopusParameters['LtmStatus']
        If ($forceOffline){
            $state = "Offline"
        }
        
        Write-Host "Setting '$ipAddress' to '$state' in '$poolName' pool."
        Set-F5.LTMPoolMemberState -Pool $poolName -Member $member -state $state
    }
}

Function Wait-ConnectionCount(){
    param(
        $f5Pools,
        [int]$maxWaitTime,
        [int]$connectionCount
    )
    
    #Start stop watch now.
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    
    Foreach ($f5Pool in $f5Pools){
        $poolInfo = $f5Pool.Split("|")
        
        $poolName = $poolInfo[0]
        $ipAddress = $poolInfo[1]
        $port = $poolInfo[2]
        
        $MemberDef = New-Object -TypeName iControl.CommonIPPortDefinition
        $MemberDef.address = $ipAddress
        $MemberDef.port = $port
        $MemberDefAofA = New-Object -TypeName "iControl.CommonIPPortDefinition[][]" 1,1
        $MemberDefAofA[0][0] = $MemberDef
        $cur_connections = 100
        
        Write-Host ("Pool name: " + $poolName)
        Write-Host ("IP Address: " + $ipAddress)
        Write-Host ("Port: " + $port)

        While ($cur_connections -gt $connectionCount -and $elapsed.ElapsedMilliseconds -lt ($maxWaitTime * 1000)){
            $MemberStatisticsA = (Get-F5.iControl).LocalLBPoolMember.get_statistics( (, $poolName), $MemberDefAofA)
            $MemberStatisticEntry = $MemberStatisticsA[0].statistics[0]
            $Statistics = $MemberStatisticEntry.statistics
            
            Foreach ($Statistic in $Statistics){
                $type = $Statistic.type;
                $value = $Statistic.value;
                If ( $type -eq "STATISTIC_SERVER_SIDE_CURRENT_CONNECTIONS" ){
                    #Just use the low value.  Odds are there aren't over 2^32 current connections. If your site is this big, you'll have to convert this to a 64 bit number.
                    $cur_connections = $value.low; 
                    Write-Host "Current Connections: $cur_connections"
                }
            }
            
            If ($cur_connections -gt $connectionCount -and $elapsed.ElapsedMilliseconds -lt ($maxWaitTime * 1000)){
                Start-Sleep -Seconds 5
            }
        }
    }
}

#endregion

#region Process

#Load the F5 powershell iControl snapin
Add-PSSnapin iControlSnapin
Initialize-F5.iControl -HostName $OctopusParameters['HostName'] -Username $OctopusParameters['Username'] -Password $OctopusParameters['Password']

Set-F5PoolState -f5Pools $f5Pools

If (($OctopusParameters['LtmStatus'] -ne "Enabled") -and ($OctopusParameters['WaitForConnections'] -eq "True"))
{
    Write-Host "Waiting for connections to drain before deploying.  This could take a while..."
    Wait-ConnectionCount -f5Pools $f5Pools -maxWaitTime $maxWaitTime -connectionCount $killConnectionWhenLE
    
    #We have now waited the desired amount, go ahead and force offline and move on with deployment.
    Set-F5PoolState -f5Pools $f5Pools -forceOffline
}


#endregion

