$ErrorActionPreference = 'Stop'

# The code for this step template is largely a copy/paste job from the
# Azure DevOps Services step template which is maintained by Redgate:
# https://github.com/red-gate/SqlCloneVSTSExtension/blob/master/ImageTask/SQLCloneCloneTask.ps1
# The code was copied and adapted on 16th May 2019.

Write-Verbose "cloneServer is $cloneServer"
Write-Verbose "cloneUser is $cloneUser"
Write-Verbose "clonePassword is $clonePassword"
Write-Verbose "imageNameForClone is $imageNameForClone"
Write-Verbose "templateName is $templateName"
Write-Verbose "cloneSqlServer is $cloneSqlServer"
Write-Verbose "cloneName is $cloneName"
Write-Verbose "deleteClone is $deleteClone"

Write-Debug "Entering script SQLCloneCloneTask.ps1"

# This line is broken: Import-Module "$PSScriptRoot\Modules\RedGate.SQLClone.PowerShell.dll"

if($cloneUser){
    $password = ConvertTo-SecureString -String $clonePassword -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cloneUser,$password

}
Connect-SqlClone -ServerUrl $cloneServer -Credential $credential
Write-Output "Connected to SQL Clone server"

        $sqlServerParts = $cloneSqlServer.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($sqlServerParts.Count -ge 3)
        {
            write-error 'SQL Server instance ' + $cloneSqlServer + ' has not been recognised, if specifying a named instance please use "machine\instance"'
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
            $message = 'SQL Server instance "' + $cloneSqlServer + '"  has not been added to SQL Clone, available instances:' + $instanceNames
            write-error $message
            exit 1
        }
        
        try
        {
            $image = Get-SqlCloneImage -Name $imageNameForClone
            Write-Output "Found image"
        }
        catch
        {
            $images = Get-SqlCloneImage
            $imageNames = "`n"
            Foreach ($cImage in $images)
            {
                $imageNames += $cImage.Name + "`n"
            }
            $message = 'SQL Clone image "' + $imageNameForClone + '"  has not been added to SQL Clone, available images:' + $imageNames
            write-error $message
            exit 1
        }
        
        if($deleteClone)
        {
            try
            {
                $clone = Get-SqlClone -Name $cloneName -Location $instance
                Write-Output "Deleting existing clone"
                Remove-SqlClone -Clone $clone | Wait-SqlCloneOperation
            }
            catch
            {
                # Clone didn't exist so nothing to do
            }
        }
        if($templateName)
        {
            Write-Output "Creating clone with template:" + $templateName
            $image | New-SqlClone -Name $cloneName -Location $instance -Template $templateName | Wait-SqlCloneOperation
        }
        else
        {            
            Write-Output "Creating clone"
            $image | New-SqlClone -Name $cloneName -Location $instance | Wait-SqlCloneOperation            
        }
        Write-Output "Finished creating clone"        

Write-Debug "Leaving script SQLCloneCloneTask.ps1"