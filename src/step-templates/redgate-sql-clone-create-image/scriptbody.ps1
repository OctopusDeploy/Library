$ErrorActionPreference = 'Stop'

# The code for this step template is largely a copy/paste job from the
# Azure DevOps Services step template which is maintained by Redgate:
# https://github.com/red-gate/SqlCloneVSTSExtension/blob/master/ImageTask/SQLCloneImageTask.ps1
# The code was copied and adapted on 16th May 2019.

Write-Verbose "cloneServer is $cloneServer"
Write-Verbose "cloneUser is $cloneUser"
Write-Verbose "clonePassword is $clonePassword"
Write-Verbose "sourceType is $sourceType"
Write-Verbose "imageName is $imageName"
Write-Verbose "imageLocation is $imageLocation"
Write-Verbose "sourceInstance is $sourceInstance"
Write-Verbose "sourceDatabase is $sourceDatabase"
Write-Verbose "sourceFileNames is $sourceFileNames"
Write-Verbose "sourceFilePassword is $sourceFilePassword"
Write-Verbose "modificationScriptFiles is $modificationScriptFiles"

Write-Debug "Entering script SQLCloneImageTask.ps1"

# This line is broken: Import-Module "$PSScriptRoot\Modules\RedGate.SQLClone.PowerShell.dll"

if($cloneUser){
    $password = ConvertTo-SecureString -String $clonePassword -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cloneUser,$password

}
Connect-SqlClone -ServerUrl $cloneServer -Credential $credential
Write-Output "Connected to SQL Clone server"

    try
    {
        $cloneImageLocation = Get-SqlCloneImageLocation $imageLocation
        Write-Output "Found image location"
    }
    catch
    {
        $imageLocations = Get-SqlCloneImageLocation
        $imageLocationNames = "`n"
        Foreach ($cImageLocation in $imageLocations)
        {
            $imageLocationNames += $cImageLocation.Path + "`n"
        }
        $message = 'SQL Clone image location "' + $imageLocation + '"  has not been added to SQL Clone, available locations:' + $imageLocationNames
        write-error $message
        exit 1
    }

    $sqlServerParts = $sourceInstance.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($sqlServerParts.Count -ge 3)
    {
        write-error 'SQL Server instance ' + $sourceInstance + ' has not been recognised, if specifying a named instance please use "machine\instance"'
        exit 1
    }
    $cloneSqlServerHost = $sqlServerParts[0]
    $instanceName = ''
    if ($sqlServerParts.Count -ge 2)
    {
        $instanceName = $sqlServerParts[1]
    }
    
    try
    {
        $instance = Get-SqlCloneSqlServerInstance -MachineName $cloneSqlServerHost -InstanceName $instanceName
        Write-Output "Found SQL Server instance"
    }
    catch
    {
        $instances = Get-SqlCloneSqlServerInstance
        $instanceNames = "`n"
        Foreach ($cInstance in $instances)
        {
            $instanceNames += $cInstance.Name + "`n"
        }
        $message = 'SQL Server instance "' + $sourceInstance + '"  has not been added to SQL Clone, available instances:' + $instanceNames
        write-error $message
        exit 1
    }

    $modificationScripts = @()
    if($modificationScriptFiles){
        $modificationFiles = $modificationScriptFiles.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
            
        Foreach ($modificationScriptFile in $modificationFiles)
        {
            if ($modificationScriptFile -Like "*.sql")
            {
                $modificationScripts += New-SqlCloneSqlScript -Path $modificationScriptFile
            }

            if ($modificationScriptFile -Like "*.dmsmaskset")
            {
                $modificationScripts += New-SqlCloneMask -Path $modificationScriptFile
            }
        }
    }
    
    if ($sourceType -eq 'database')
    {
        Write-Output "Source type = database"
        Write-Output "Creating image"
        $NewImage = New-SqlCloneImage -Name $imageName -SqlServerInstance $instance -DatabaseName $sourceDatabase -Destination $cloneImageLocation -Modifications $modificationScripts | Wait-SqlCloneOperation    
        Write-Output "Finished creating image"
    }
    else
    {
        Write-Output "Source type = backup"
        $backupFiles = $sourceFileNames.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
        Write-Output "Creating image from backup"
        if($sourceFilePassword)
        {
            $NewImage = New-SqlCloneImage -Name $imageName -SqlServerInstance $instance -BackupFileName $backupFiles -BackupPassword $sourceFilePassword -Destination $cloneImageLocation -Modifications $modificationScripts | Wait-SqlCloneOperation
        }
        else
        {
            $NewImage = New-SqlCloneImage -Name $imageName -SqlServerInstance $instance -BackupFileName $backupFiles -Destination $cloneImageLocation -Modifications $modificationScripts | Wait-SqlCloneOperation
        }
        Write-Output "Finished creating image from backup"        
    }

    

Write-Debug "Leaving script SQLCloneImageTask.ps1"
