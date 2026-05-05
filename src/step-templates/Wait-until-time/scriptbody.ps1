if(($DefaultTargetTime -eq $null-or $DefaultTargetTime -eq '') -and ($TargetTime -eq $null -or $TargetTime -eq'') ){
    Write-Output 'Deploy will start immediately because neither TargetTime or DefaultTargetTime is set' 
}else{
    
    if($TargetTime -eq $null){
        $deployTime = get-date($DefaultTargetTime)
        Write-Output 'DeployTime is set to DefaultTargetTime since TargetTime is not configured as a variable for this build scope.'
    }else{
        $deployTime = get-date($TargetTime)
    }
    if((get-date)  -ge $deployTime){
        $deployTime = $deployTime.AddDays(1)
    }
    Write-Output ('Deploy will pause until ' + $deployTime)

    
    do {
    	Start-Sleep 1
    }
    until ((get-date) -ge $deployTime)
}