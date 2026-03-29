function CheckSQLServerInAOAG($SqlServer, $PrimaryNode)
{
    $serverConn = new-object ('Microsoft.SqlServer.Management.Common.ServerConnection') $SqlServer
    
    try{
            $serverConn.Connect();
            $server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $serverConn  
            if (!$server.IsHadrEnabled)
            {
    	        Write-Host "The SQL Server [$SqlServer] is not configured with High Availability Group."
            }
            else
            {
                # Get SQL Availability Group
                $SQLAvailabilityGroup = $server.AvailabilityGroups[0]
    
                Write-Host "Getting High Availability Group properties."
                
                # Get SQL Availability Groups Properties
	            $SQLAvailabilityGroupName = $SQLAvailabilityGroup.Name;
	            $SQLAvailabilityGroupID = $SQLAvailabilityGroup.Id;
	            $SQLAvailabilityGroupGuid = $SQLAvailabilityGroup.UniqueId;
	            $SQLLocalReplicaRole = $SQLAvailabilityGroup.LocalReplicaRole;
	            $SQLPrimaryReplicaServerName = $SQLAvailabilityGroup.PrimaryReplicaServerName;
	            
	            Write-Host	"SQLAvailabilityGroupName : $SQLAvailabilityGroupName"
                Write-Host	"SQLAvailabilityGroupID : $SQLAvailabilityGroupID"
                Write-Host	"SQLAvailabilityGroupGuid : $SQLAvailabilityGroupGuid"
                Write-Host	"SQLLocalReplicaRole : $SQLLocalReplicaRole"
                Write-Host	"SQLPrimaryReplicaServerName : $SQLPrimaryReplicaServerName"    
    
                if ($SQLPrimaryReplicaServerName -eq $PrimaryNode)
                {
    	            Write-Host "Setting Octopus variable SQLIsOnSecondary false"
                    Set-OctopusVariable -name "SQLIsOnSecondary" -value "false"        
                }
                else 
                {
    	            Write-Host "Setting Octopus variable SQLIsOnSecondary true"
    	            Set-OctopusVariable -name "SQLIsOnSecondary" -value "true"
                }
            }
        }
        catch
        {
            throw "Could not connect to server $SqlServer.  Exception is:`r`n$($_ | fl -force | out-string)"
        }
        finally
        {
            $serverConn.Disconnect();
        }
}

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null
CheckSQLServerInAOAG $HAGroupSQLServer $HAGroupPrimaryNode