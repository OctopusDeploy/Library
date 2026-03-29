<#
This script will take the existing configuration (does not include website files) and back it up on the IIS Server, which can then be later restored if needed.

To view existing backups for restore operation, find the latest backup here:
    $env:Windir\System32\inetsrv\backup

To restore, use the following commands:
    Restore-WebConfiguration -Name "IISConfigBackup"
    iisreset

Reference Articles:
https://technet.microsoft.com/en-us/library/hh867851(v=wps.630).aspx
https://technet.microsoft.com/en-us/library/hh867862(v=wps.630).aspx
#>

# clear all backed up configurations first
Remove-WebConfigurationBackup

# perform backup
Backup-WebConfiguration -Name "IISConfigBackup"
