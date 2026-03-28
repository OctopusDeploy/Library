###----------------------------###
###                            ###
###check Windows service status###
###                            ###
###----------------------------###

$servicename=$OctopusParameters['servicenamewin']
$desiredstate=$OctopusParameters['servicewinstatus']
$hostslist=$OctopusParameters['winhostlist']

###hosts list comma-separated or single host
$hostl=$hostslist.Split(",")
$hostl

foreach($h in $hostl){
    Write-Output "Running on $h"
    #check the status of the service on remote host
    $remotestatus=invoke-command -computername $h {(Get-Service -Name $servicename).Status}
    $status=$remotestatus.Value
    if($status){
        try{
            if($status -like $desiredstate){
                Write-Output "The service $servicename is correctly $desiredstate on $h"
            }
            else{
                Write-Error "The service $servicename is NOT $desiredstate. Currently state is $status"
            
            }
        }
        catch{
            Write-Error "Is not possible to determinate the status for service $servicename"
        }

    }
    else{
        Write-Error "Error on retrieving the status. Invalid service name or host $h"
    }
}

###@author:fedele_mattia