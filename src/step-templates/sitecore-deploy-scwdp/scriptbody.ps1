try { 
  $applicationPath = $OctopusParameters["SCWDP Application Path"]
  $coreConnection = $OctopusParameters["SCWDP Core Admin Connection String"]
  $masterConnection = $OctopusParameters["SCWDP Master Admin Connection String"]
  $webConnection = $OctopusParameters["SCWDP Web Admin Connection String"] 
  $msDeploy = $OctopusParameters["SCWDP MsDeploy Path"] 
  
  $package = $OctopusParameters["SCWDP Package"]

  $cmd = "`""+$msDeploy+"`" -verb:sync -source:package=`""+$package+"`" -dest:auto -enableRule:DoNotDeleteRule -setParam:`"Application Path`"=`""+$applicationPath+"`" -setParam:`"Core Admin Connection String`"=`""+$coreConnection+"`" -setParam:`"Master Admin Connection String`"=`""+$masterConnection+"`" -setParam:`"Web Admin Connection String`"=`""+$webConnection+"`" -verbose"

  Write-Output $cmd
  cmd.exe /c $cmd
}
catch {
  Write-Error "An error occurred:"
  Write-Error $_
}