$itemsParameter = $OctopusParameters['Items']
$readPermissionsTo = $OctopusParameters['ReadPermissionsTo']
$writePermissionsTo = $OctopusParameters['WritePermissionsTo']
$modifyPermissionsTo = $OctopusParameters['ModifyPermissionsTo']

if($readPermissionsTo)
{
    $readUsers = $readPermissionsTo.Split(",")
}

if($writePermissionsTo)
{
    $writeUsers = $writePermissionsTo.Split(",")
}

if($modifyPermissionsTo)
{
    $modifyUsers = $modifyPermissionsTo.Split(",")
}

$items = $itemsParameter.Split(",")
foreach($item in $items) 
{
    # Check path exists
    if(!(Test-Path $item))
    {
        throw "$item does not exist"
    }

    Write-Host "Path: $item"
    # Assign read permissions
    foreach($user in $readUsers)
    {
        Write-Host "  Adding read permissions for $user"
        $acl = (Get-Item $item).GetAccessControl('Access')
        $acl.SetAccessRuleProtection($False, $False)
        $rule = 
            if ($acl -is [System.Security.AccessControl.DirectorySecurity])
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Read", "ContainerInherit, ObjectInherit", "None", "Allow")
                }
                else
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Read", "Allow")
                }
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }

    # Assign write permissions
    foreach($user in $writeUsers)
    {
        Write-Host "  Adding write permissions for $user"
        $acl = (Get-Item $item).GetAccessControl('Access')
        $acl.SetAccessRuleProtection($False, $False)
        $rule = 
            if ($acl -is [System.Security.AccessControl.DirectorySecurity])
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Write", "ContainerInherit, ObjectInherit", "None", "Allow")
                }
                else
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Write", "Allow")
                }
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }

    # Assign modify permissions
    foreach($user in $modifyUsers)
    {
        Write-Host "  Adding modify permissions for $user"
        $acl = (Get-Item $item).GetAccessControl('Access')
        $acl.SetAccessRuleProtection($False, $False)
        $rule = 
            if ($acl -is [System.Security.AccessControl.DirectorySecurity])
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Modify", "ContainerInherit, ObjectInherit", "None", "Allow")
                }
                else
                {
                    New-Object System.Security.AccessControl.FileSystemAccessRule($user, "Modify", "Allow")
                }
        $acl.AddAccessRule($rule)
        Set-Acl $item $acl
    }
}

Write-Host "Complete"
