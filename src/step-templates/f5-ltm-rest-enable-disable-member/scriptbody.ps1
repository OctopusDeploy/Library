# Based on the F5 template by spuder.
# This template has been translated to use REST instead of the iControl SOAP commandlets.
# https://www.powershellgallery.com/packages/F5-LTM/1.4.297
# https://devcentral.f5.com/s/articles/powershell-module-for-the-f5-ltm-rest-api
Import-Module -Name F5-LTM

function WaitFor-ConnectionCount() 
{ 
    param(
        $pool_name, 
        $member,
        [int]$MaxWaitTime = 300, #defaults to 5 minutes
        $ConnectionCount = 0
    )
    $member_addr = $member

    Write-Host "Waiting for current connections to drop to "$ConnectionCount

    $cur_connections = 100;
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew();

    while ( $cur_connections -gt $ConnectionCount -and $elapsed.ElapsedMilliseconds -lt ($MaxWaitTime * 1000))
    {
        $MemberStatisticsA = Get-PoolMemberStats -PoolName $pool_name -Address $member_addr
        $MemberStatisticEntry = $MemberStatisticsA.'serverside.curConns'
        $cur_connections = $MemberStatisticEntry.Value; 

        Write-Host "Current Connections: $cur_connections"

        Start-Sleep -s 5
    }
}

$Pool = $OctopusParameters['F5LTM.PoolName'].trim();

If ([string]::IsNullOrWhiteSpace($OctopusParameters['F5LTM.MemberIP'])) {
    Write-Host "No IP Adress was provided on the 'LTM Member IP`, using [System.Net.Dns]::GetHostAddresses to resolve it"
    $ip = $([System.Net.Dns]::GetHostAddresses("$($OctopusParameters['Octopus.Machine.Hostname'])") | Where {$_.AddressFamily -ne 'InterNetworkV6'}).IpAddressToString
    if ($ip -is [array]) {
      Write-Host "Found multiple ipv4 addresses, using first address $($ip[0])"
      $ip = $ip[0]
    }
} Else {
    $ip = $OctopusParameters['F5LTM.MemberIP']
}

$Member = $ip

Write-Host "Member is $Member"

# Gets the hostname of the current machine being deployed.
$curhost = hostname
$hostname = $OctopusParameters['F5LTM.HostName']
$username = $OctopusParameters['F5LTM.Username']
$password = ConvertTo-SecureString $OctopusParameters['F5LTM.Password'] -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)

Write-host "Currently deploying to $curhost"

If (($OctopusParameters['F5LTM.EnableOrDisable'] -ne "Enabled") -and ($OctopusParameters['F5LTM.WaitForConnections'] -eq "True"))
{
    New-F5Session -LTMName $hostname -LTMCredentials $credential

    Write-Host "Setting $Member to $($OctopusParameters['F5LTM.EnableOrDisable']) in $Pool pool";

    Disable-PoolMember -PoolName $Pool -Address $Member

    Write-Host "Waiting for connections to drain before deploying.  This could take a while...."

    WaitFor-ConnectionCount -pool_name $Pool -member $Member -MaxWaitTime $OctopusParameters['F5LTM.MaxWaitTime'] -ConnectionCount $OctopusParameters['F5LTM.ConnectionCount']

    if ($OctopusParameters['F5LTM.EnableOrDisable'] -eq "Disabled") 
    {
        Write-Host "Setting $Member to Offline in $Pool pool";

        Disable-PoolMember -PoolName $Pool -Address $Member -Force
    }
}
Else
{
    New-F5Session -LTMName $hostname -LTMCredentials $credential

    Write-host "Setting $Member to $($OctopusParameters['F5LTM.EnableOrDisable']) in $Pool pool."

    if ($OctopusParameters['F5LTM.EnableOrDisable'] -eq "Disabled") 
    {
        Disable-PoolMember -PoolName $Pool -Address $Member -Force
    } 
    Else
    {
        Enable-PoolMember -PoolName $Pool -Address $Member
    }
}