#octopus variables
$node = "#{node}"
$pool = "#{pool}"
$f5pass = "#{f5pass}"
$f5user = "#{f5user}"
$f5ipv4 = "#{f5ipv4}"
$numconn = "#{numconn}"
$timeout = "#{timeout}"
$action= "#{action}"
$f5_ip=$f5ipv4.split(',')

#whitout ssl certificate
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback=@"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore();

#F5 Credentials
$username= $f5user
$password= $f5pass | ConvertTo-SecureString -AsPlainText -Force
$cred= New-Object System.Management.Automation.PSCredential $username, $password
Write-Output "Cred: $cred"

#retrieve Active F5 server
function Get-StatusF5{
    param(
        $ipserver,
        $credential
    )
    $result=Invoke-WebRequest -Uri "https://$ipserver/mgmt/tm/cm/failover-status" -Credential $credential -ErrorAction Ignore -UseBasicParsing
    $items=$result.Content | ConvertFrom-Json
    $status=$items.entries.'https://localhost/mgmt/tm/cm/failover-status/0'.nestedStats.entries.status
    return $status
}

foreach($ipv4 in $f5_ip){
    $state=Get-StatusF5 -ipserver $ipv4 -credential $cred
    if (($state.description) -like "ACTIVE"){
        $master=$ipv4
        Write-Output "F5 master ACTIVE: $master"
    }
    else{
        Write-Output "$ipv4 is not master active"
    }
}
if (!$master){
    Write-Error "ATTENTION - F5 servers are incorrect"
}

#retrieve informations
$result=Invoke-WebRequest -Uri "https://$master/mgmt/tm/ltm/pool/$pool/members" -Credential $cred -UseBasicParsing
$items=$result.Content | ConvertFrom-Json
$items.items
$name=($items.items | where{$_.name -like "*$node*"}).name
Write-Host "Nome del nodo: $name"

#action based on $action
if($action -like "Enable"){
    $state ='{"state": "user-up", "session": "user-enabled"}' ###ENABLED
    Write-Output "Action: Enable $name"
    Invoke-WebRequest -Uri "https://$master/mgmt/tm/ltm/pool/$pool/members/~Common~$name"  -Credential $cred -ContentType application/json -Method PUT -Body $state  -Verbose -UseBasicParsing
}
else{
    if($action -like "Disable"){
        $state ='{"state": "user-up", "session": "user-disabled"}' ###Disabled
        Write-Output "Action: Enable $name"
        Invoke-WebRequest -Uri "https://$master/mgmt/tm/ltm/pool/$pool/members/~Common~$name"  -Credential $cred -ContentType application/json -Method PUT -Body $state  -Verbose -UseBasicParsing
    }
    else{
        if($action -like "Offline"){
            $state ='{"state": "user-down", "session": "user-disabled"}' ###FORCEDOFFLINE
            Invoke-WebRequest -Uri "https://$master/mgmt/tm/ltm/pool/$pool/members/~Common~$name"  -Credential $cred -ContentType application/json -Method PUT -Body $state  -Verbose -UseBasicParsing
            $current_conn=$numconn + 00

            [int]$time = 0
            Write-Output "Connections accepted: $numconn"
            while($current_conn -gt $numconn){
                if($second -ne $timeout){
                    $url="https://$master/mgmt/tm/ltm/pool/$pool/members/~Common~$name" + '/stats?$select=serverside.curConns'
                    Start-Sleep 1
                    [int]$second = $time++
                    $result= Invoke-WebRequest -Uri $url -Credential $cred -UseBasicParsing
                    $item=$result.Content | ConvertFrom-Json
                    $current_conn=($item.entries.'serverside.curConns').value
                    Write-Host "Second: $second - Connections: $current_conn"
                }
                else{
                    Write-Output "Timeout - $current_conn connections stopped"
                    $current_conn= 0
                }
            }
    }
        else{
            Write-Error "ACTION IS NOT ACCEPTED"
        }
}
}
Start-sleep 10
Write-Host "Go to next step"
