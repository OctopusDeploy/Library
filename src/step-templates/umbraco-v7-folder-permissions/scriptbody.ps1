$PhysicalPath = "$WebsiteDirectory"
$appPoolAccount = "IIS APPPOOL\$ApplicationPoolName"
$readExecute = $appPoolAccount,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow"
$read = $appPoolAccount,"Read","ContainerInherit,ObjectInherit","None","Allow"
$modify = $appPoolAccount,"Modify","ContainerInherit,ObjectInherit","None","Allow"
$fileModify = $appPoolAccount,"Modify","Allow"
$objects = @{}
$objects["App_Browsers"] = $readExecute
$objects["App_Code"] = $modify
$objects["App_Data"] = $modify
$objects["App_Plugins"] = $modify
$objects["bin"] = $modify
$objects["Config"] = $modify
$objects["Css"] = $modify
$objects["MacroScripts"] = $modify
$objects["Masterpages"] = $modify
$objects["Media"] = $modify
$objects["Scripts"] = $modify
$objects["Umbraco"] = $modify
$objects["Umbraco_Client"] = $modify
$objects["UserControls"] = $modify
$objects["Views"] = $modify
$objects["Web.config"] = $fileModify
$objects["Xslt"] = $modify
foreach($object in $objects.Keys){
    try {
        $path = Join-Path $PhysicalPath $object
        $acl = Get-ACL $path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($objects[$object])
        $acl.AddAccessRule($rule)
        Set-Acl $path $acl
        Get-Acl $path | Format-List
    }
    catch [System.Exception]
    {
        Write-Host "Unable to set ACL on" Join-Path $PhysicalPath $object
    }
}