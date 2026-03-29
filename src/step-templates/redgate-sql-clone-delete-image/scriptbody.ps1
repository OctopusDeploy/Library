$ErrorActionPreference = 'Stop'

# The code for this step template is largely a copy/paste job from the
# Azure DevOps Services step template which is maintained by Redgate:
# https://github.com/red-gate/SqlCloneVSTSExtension/blob/master/DeleteImageTask/SQLCloneDeleteImageTask.ps1
# The code was copied and adapted on 16th May 2019.

Write-Verbose "cloneServer is $cloneServer"
Write-Verbose "cloneUser is $cloneUser"
Write-Verbose "clonePassword is $clonePassword"
Write-Verbose "imageName is $imageName"

# This line is broken: Import-Module "$PSScriptRoot\Modules\RedGate.SQLClone.PowerShell.dll"

if($cloneUser){
    $password = ConvertTo-SecureString -String $clonePassword -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $cloneUser,$password

}
Connect-SqlClone -ServerUrl $cloneServer -Credential $credential
Write-Output "Connected to SQL Clone server"
        
        try
        {
            $image = Get-SqlCloneImage -Name $imageName
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
            $message = 'SQL Clone image ' + $imageName + ' does not exist, available images: ' + $imageNames
            write-error $message
            exit 1
        }
        
        Write-Output "Deleting image"
        Remove-SqlCloneImage -Image $image | Wait-SqlCloneOperation
        Write-Output "Finished deleting image"     

Write-Debug "Leaving script SQLCloneDeleteImageTask.ps1"
