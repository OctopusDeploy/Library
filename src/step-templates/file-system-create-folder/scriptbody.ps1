$item = $OctopusParameters['FolderPath']
$readPermissionsTo = $OctopusParameters['ReadPermissionsTo']
$writePermissionsTo = $OctopusParameters['WritePermissionsTo']
$modifyPermissionsTo = $OctopusParameters['ModifyPermissionsTo']


Write-Host "Creating folder $item with permissions."

if((Test-Path $item))
{
    Write-Host "Folder $item already exists"
}
else
{
    New-Item -ItemType directory -Path $item -force
}

# Check item exists
if(!(Test-Path $item))
{
    throw "$item does not exist"
}

# Assign read permissions

if($readPermissionsTo)
{
    $users = $readPermissionsTo.Split(",")
    foreach($user in $users)
    {
        Write-Host "Adding read permissions for $user"
        $acl = Get-Acl $item
        $acl.SetAccessRuleProtection($False, $False)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $user, "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }
}

# Assign write permissions

if($writePermissionsTo)
{
    $users = $writePermissionsTo.Split(",")
    foreach($user in $users)
    {
        Write-Host "Adding write permissions for $user"
        $acl = Get-Acl $item
        $acl.SetAccessRuleProtection($False, $False)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $user, "Write", "ContainerInherit, ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }
}

# Assign modify permissions

if($modifyPermissionsTo)
{
    $users = $modifyPermissionsTo.Split(",")
    foreach($user in $users)
    {
        Write-Host "Adding modify permissions for $user"
        $acl = Get-Acl $item
        $acl.SetAccessRuleProtection($False, $False)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $user, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }
}

Write-Host "Complete"