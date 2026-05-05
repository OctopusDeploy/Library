#Load the F5 powershell iControl snapin
#https://help.octopus.com/t/the-windows-powershell-snap-in-webadministration-is-not-installed-on-this-computer/4290
Add-PSSnapin iControlSnapin;

function WaitFor-ConnectionCount() 
{ 
    param(
        $pool_name, 
        $member,
        [int]$MaxWaitTime = 300, #defaults to 5 minutes
        $ConnectionCount = 0
    )
    $vals = $member.Split( (, ':'));
    $member_addr = $vals[0];
    $member_port = $vals[1];

    Write-Host "Waiting for current connections to drop to "$OctopusParameters['ConnectionCount']

    $MemberDef = New-Object -TypeName iControl.CommonIPPortDefinition;
    $MemberDef.address = $member_addr;
    $MemberDef.port = $member_port;
    $MemberDefAofA = New-Object -TypeName "iControl.CommonIPPortDefinition[][]" 1,1
    $MemberDefAofA[0][0] = $MemberDef;
    $cur_connections = 100;
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew();

    while ( $cur_connections -gt $ConnectionCount -and $elapsed.ElapsedMilliseconds -lt ($MaxWaitTime * 1000))
    {
        $MemberStatisticsA = (Get-F5.iControl).LocalLBPoolMember.get_statistics( (, $pool_name), $MemberDefAofA);
        $MemberStatisticEntry = $MemberStatisticsA[0].statistics[0];
        $Statistics = $MemberStatisticEntry.statistics;
        foreach ($Statistic in $Statistics)
        {
            $type = $Statistic.type;
            $value = $Statistic.value;
            if ( $type -eq "STATISTIC_SERVER_SIDE_CURRENT_CONNECTIONS" )
            {
                # just use the low value.  Odds are there aren't over 2^32 current connections.
                # If your site is this big, you'll have to convert this to a 64 bit number.
                $cur_connections = $value.low; 
                Write-Host "Current Connections: $cur_connections"
            }
        }
        Start-Sleep -s 5
    }
}

$Pool = $OctopusParameters['PoolName'].trim();

If ([string]::IsNullOrWhiteSpace($OctopusParameters['MemberIP'])) {
    Write-Host "No IP Adress was provided on the 'LTM Member IP`, using [System.Net.Dns]::GetHostAddresses to resolve it"
    $ip = $([System.Net.Dns]::GetHostAddresses("$($OctopusParameters['Octopus.Machine.Hostname'])") | Where {$_.AddressFamily -ne 'InterNetworkV6'}).IpAddressToString
    if ($ip -is [array]) {
      Write-Host "Found multiple ipv4 addresses, using first address $($ip[0])"
      $ip = $ip[0]
    }
} Else {
    $ip = $OctopusParameters['MemberIP']
}

$Member = $ip+":"+$OctopusParameters['MemberPort']
Write-Host "Member is $Member"

# Gets the hostname of the current machine being deployed.
$curhost = hostname

Write-host "Currently deploying to $curhost"

If (($OctopusParameters['EnableOrDisable'] -ne "Enabled") -and ($OctopusParameters['WaitForConnections'] -eq "True"))
{
    Initialize-F5.iControl -HostName $OctopusParameters['HostName'] -Username $OctopusParameters['Username'] -Password $OctopusParameters['Password']
    Write-Host "Setting $curhost to $($OctopusParameters['EnableOrDisable']) in $Pool pool";
    Set-F5.LTMPoolMemberState -Pool $Pool -Member $Member -state $OctopusParameters['EnableOrDisable'];
    Write-Host "Waiting for connections to drain before deploying.  This could take a while...."
    WaitFor-ConnectionCount -pool_name $Pool -member $Member -MaxWaitTime $OctopusParameters['MaxWaitTime'] -ConnectionCount $OctopusParameters['ConnectionCount']
    if ($OctopusParameters['EnableOrDisable'] -eq "Disabled") 
    {
        Write-Host "Setting $curhost to Offline in $Pool pool";
        # We've now waited the desired amount, go ahead and force offline and move on with deployment
        Set-F5.LTMPoolMemberState -Pool $Pool -Member $Member -state Offline;
    }
}
Else
{
    Initialize-F5.iControl -HostName $OctopusParameters['HostName'] -Username $OctopusParameters['Username'] -Password $OctopusParameters['Password']
    Write-host "Setting $curhost to $($OctopusParameters['EnableOrDisable']) in $Pool pool."
    Set-F5.LTMPoolMemberState -Pool $Pool -Member $Member -state $OctopusParameters['EnableOrDisable'];
}
