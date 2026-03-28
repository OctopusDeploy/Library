$Zserver="#{zserver}"
$Zuser="#{zuser}"
$Zpassword="#{zpass}"
$Zhost="#{zhost}"
$setgmt=#{gmt}
$hours=#{hours}
$action="#{action}"
$number="#{number}"

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

function Get-Auth{
    param(
        $server,
        $user,
        $pass,
        $url
    )
    $body='{"jsonrpc": "2.0", "method": "user.login", "params": {"user": "'+"$user"+'", "password": "'+"$pass"+'"}, "id": 1, "auth": null}'
    try {
        $key=Invoke-WebRequest -Uri "$url" -ContentType application/json-rpc -Body $body -Method Put -UseBasicParsing
        } catch [Exception] {
            Write-Error "Error: cannot connect to zabbix server ($($_.Exception.Message)), check hostname/url! Frequently zabbix is installed on a virtual folder like {hostname}/zabbix, please include the folder into the hostname variable.`r`n" -ErrorAction Stop
        }
    $token=($key.Content | ConvertFrom-Json).result
    return $token
}

function Remove-Maintenance{
    param(
        $srvr,
        $usr,
        $pswd,
        $uri,
        $mname
    )
    $remove='{"jsonrpc": "2.0", "method": "maintenance.get", "params": {"output": "extend", "selectHosts": "extend", "selectTimeperiods": "extend"},"auth": "'+"$auth"+'","id": 1}'

    $maintenace=Invoke-WebRequest -Uri "$uri" -ContentType application/json-rpc -Body $remove -Method Put -UseBasicParsing
    $select= ($maintenace.Content | ConvertFrom-Json).result | where{$_.name -like "$mname"}
    $id=$select.maintenanceid
    if($id){
        Write-Output "Remove maintenance ID: $id"
        $rmv='{"jsonrpc": "2.0", "method": "maintenance.delete", "params": ["'+"$id"+'"], "auth": "'+"$auth"+'","id": 1}'
        $actionremove=Invoke-WebRequest -Uri "$uri" -ContentType application/json-rpc -Body $rmv -Method Put -UseBasicParsing
        $check=(($actionremove.Content | ConvertFrom-Json).result).maintenanceids
        if($check -like $id){
            Write-Output "Maintenance $id removed"
        }
        else{
            Write-Error "Something wrong. Please contact your system administrator"
        }
    }
    else{
        Write-Error "NO Maintenance ID - contact your system administrator"
    }
}

###GLOBAL VARIABLES###
if (!$Zserver.StartsWith("http")) { $Zserver="http://$Zserver" } 
$Zurl="$Zserver/api_jsonrpc.php"
$maintenancename="Octo-$number-$Zhost"

###GET AUTH FROM ZABBIX SERVER###
$auth=Get-Auth -server $Zserver -user $Zuser -pass $Zpassword -url $Zurl
if ($auth -eq $null) { 
    Write-Error "Authentication failure for user $Zuser on server $Zserver!" -ErrorAction Stop 
    exit
}

###GET HOST ID###
$content='{"jsonrpc": "2.0", "method": "host.get", "params": {"output": "extend", "filter": {"host": "'+"$Zhost"+'"}},"auth": "'+"$auth"+'","id": 1}'
$zabbixhost=Invoke-WebRequest -Uri "$Zurl" -ContentType application/json-rpc -Body $content -Method Put -UseBasicParsing
$nameserver=$zabbixhost.Content | ConvertFrom-Json
$hostid=$nameserver.result.hostid
if($hostid){
    Write-Output "Host $Zhost found with ID: $hostid"
}
else{
    Write-Error "Host $Zhost not found, or user not authorized for this host - please contact your system administrator!"
    exit
}

###ADD NEW MAINTENANCE###
if ($action -eq "create"){
    ###REMOVE MAINTENANCE IF ALREADY EXISTS WITH THE SAME NAME###
    $remove='{"jsonrpc": "2.0", "method": "maintenance.get", "params": {"output": "extend", "selectHosts": "extend", "selectTimeperiods": "extend"},"auth": "'+"$auth"+'","id": 1}'
    $maintenace=Invoke-WebRequest -Uri "$Zurl" -ContentType application/json-rpc -Body $remove -Method Put -UseBasicParsing

    $select= ($maintenace.Content | ConvertFrom-Json).result | where{$_.name -like "$maintenancename"}
    if(!$select){
        Write-Output "No maintenance with the same name is already registered"
    }
    else{
        Remove-Maintenance -srvr $Zserver -usr $Zuser -pswd $Zpassword -uri $Zurl -mname $maintenancename
    }

    ###START TO CREATE NEW MAINTENANCE###
    $since=[int][double]::Parse((get-date -UFormat %s))
    $till=0

    ###ATTENTION ON GMT - THIS WORK FOR ITALIAN ZONE AND TAKES DAYLIGHT SAVINGSTIME FROM###
    ###start check your ZABBIX configuration###
    $workdate=(Get-Date)
    if (![int32]::TryParse($setgmt, [ref] $gmt)) { $gmt=([TimeZoneInfo]::Local.BaseUtcOffset).Hours }
    if ($workdate.IsDaylightSavingTime()) { $gmt+=1 }

    $min=$workdate.AddHours(-$gmt).Minute
    $h=$workdate.AddHours(-$gmt).Hour
    $minutetoseconds=$min*=60
    $hourstoseconds=$h*=3600
    $starttime=$minutetoseconds+=$hourstoseconds
    $seconds=$hours*=3600

    $sincesum=$since
    $till=$sincesum+=$seconds
    $since=$since-=(60*60*$gmt)
    $till=$till-=(60*60*$gmt)

    ###stop check your ZABBIX configuration###
    $add='{"jsonrpc": "2.0", "method": "maintenance.create", "params": {"name": "'+"$maintenancename"+'", "active_since": "'+"$since"+'", "active_till": '+"$till"+', "hostids": ["'+$hostid+'"], "timeperiods": [{"timeperiod_type": 0, "start_time": '+$starttime+', "period": '+$seconds+'}]}, "auth": "'+$auth+'", "id": 1}'
    $maintenance=Invoke-WebRequest -Uri "$Zurl" -ContentType application/json-rpc -Body $add -Method Put -UseBasicParsing
    $check=(($maintenance.Content | ConvertFrom-Json).result).maintenanceids
    if($check){
        Write-Output "Maintenance $check created"
    }
    else{
        Write-Error "Something wrong. Please contact your system administrator"
    }
}
else{
    if($action -eq "remove"){
        Remove-Maintenance -srvr $Zserver -usr $Zuser -pswd $Zpassword -uri $Zurl -mname $maintenancename        
    }
    else{
        Write-Error "Action $action not possible"
    }
}