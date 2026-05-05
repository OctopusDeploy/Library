$MSMQQueues = $OctopusParameters['MSMQQueues']
$MSMQResetPermissions = $OctopusParameters['MSMQResetPermissions']
$MSMQResetDomains = $OctopusParameters['MSMQResetDomains']
$MSMQUsers = $OctopusParameters['MSMQUsers']
$MSMQPermAllow = $OctopusParameters['MSMQPermAllow']
$MSMQPermDeny = $OctopusParameters['MSMQPermDeny']
$MSMQAdminUsers = $OctopusParameters['MSMQAdminUsers']
$MSMQPermAdminAllow = $OctopusParameters['MSMQPermAdminAllow']
$MSMQPermAdminDeny = $OctopusParameters['MSMQPermAdminDeny']

Write-Verbose "`$MSMQQueues = $MSMQQueues"
Write-Verbose "`$MSMQResetPermissions = $MSMQResetPermissions"
Write-Verbose "`$MSMQResetDomains = $MSMQResetDomains"
Write-Verbose "`$MSMQUsers = $MSMQUsers"
Write-Verbose "`$MSMQPermAllow = $MSMQPermAllow"
Write-Verbose "`$MSMQPermDeny = $MSMQPermDeny"
Write-Verbose "`$MSMQAdminUsers = $MSMQAdminUsers"
Write-Verbose "`$MSMQPermAdminAllow = $MSMQPermAdminAllow"
Write-Verbose "`$MSMQPermAdminDeny = $MSMQPermAdminDeny"

#Split the Queues into an array
$arrQueues = $MSMQQueues.split(";")
foreach ($Queue in $arrQueues) 
{
    #Does Queue Exists Already?
    $thisQueue = Get-MSMQQueue $Queue
    if (!$thisQueue)
    {
        #not found, create
        Write-Output "Creating Queue: " $Queue
        New-MsmqQueue -Name "$Queue" -Label "private$\$Queue" -Transactional | Out-Null
        $thisQueue = Get-MSMQQueue $Queue    
    }
    else
    {
        Write-Output "Queue Exists: " $thisQueue.QueueName
        
        if($MSMQResetPermissions -eq "True")
        {
            foreach($domain in $MSMQResetDomains.split(";"))
            {
                # reset permissions
                $QueuePermissions = $thisQueue | Get-MsmqQueueACL
                foreach ($AccessItem in $MSMQQueuePermissions)
                {
                    $userName = [Environment]::UserName
                    if($AccessItem.AccountName -NotLike "*$userName") # not current user
                    {
                        $domain = "$($domain)*" #append * to end of domain
                        if ($AccessItem.AccountName -Like "$($domain)*")
                        {
                            Write-Output "Removing Permissions $($AccessItem.Right) for $($AccessItem.AccountName)"
                            Try
                            {
                                $thisQueue | Set-MsmqQueueACL -UserName $AccessItem.AccountName -Remove $AccessItem.Right | Out-Null
                            }
                            Catch
                            {
                                Write-Output "Could not set permissions item $_.Exception.Message"
                                Break
                            }
                        }
                    }
                }
            }
        }
    }

    #set acl for users
    $arrUsers = $MSMQUsers.split(";")
    foreach ($User in $arrUsers)     
    {    
        if ($User)
        {    
            Write-Output "Adding ACL for User: " $User        
            
            #allows
            if ($MSMQPermAllow)
            {
                $arrPermissions = $MSMQPermAllow.split(";")
                foreach ($Permission in $arrPermissions)     
                {
                    $thisQueue | Set-MsmqQueueAcl -UserName $User -Allow $Permission | Out-Null                
                    Write-Output "ACL Allow set: $Permission"
                }
            }
                
            #denies
            if ($MSMQPermDeny)
            {
                $arrPermissions = $MSMQPermDeny.split(";")
                foreach ($Permission in $arrPermissions)     
                {
                    $thisQueue | Set-MsmqQueueAcl -UserName $User -Deny $Permission | Out-Null
                    Write-Output "ACL Deny set: $Permission"
                }
            }
        }
    }   
    
    
    $arrAdminUsers = $MSMQAdminUsers.split(";") 
    foreach ($User in $arrAdminUsers)     
    {    
        if ($User)
        { 
            Write-Output "Adding ACL for Admin User: " $User        
            
            #allows
            if ($MSMQPermAdminAllow)
            {
                $arrPermissions = $MSMQPermAdminAllow.split(";")
                foreach ($Permission in $arrPermissions)     
                {
                    $thisQueue | Set-MsmqQueueAcl -UserName $User -Allow $Permission | Out-Null                
                    Write-Output "ACL Allow admin set: $Permission"
                }
            }
                
            #denies
            if ($MSMQPermAdminDeny)
            {
                $arrPermissions = $MSMQPermAdminDeny.split(";")
                foreach ($Permission in $arrPermissions)     
                {
                    $thisQueue | Set-MsmqQueueAcl -UserName $User -Deny $Permission | Out-Null
                    Write-Output "ACL Deny admin set: $Permission"
                }
            }
        }
    }
}