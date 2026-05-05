# Code based on Stack Overflow solution https://stackoverflow.com/a/21235462/201382 from @grenade (https://stackoverflow.com/users/68115/grenade)

$grantLogonAsServiceAccountName = $OctopusParameters['GrantLogonAsServiceAccountName']

$tempPath = [System.IO.Path]::GetTempPath()
$import = Join-Path -Path $tempPath -ChildPath "import.inf"
if (Test-Path $import) { 
    Remove-Item -Path $import -Force 
}

$export = Join-Path -Path $tempPath -ChildPath "export.inf"
if (Test-Path $export) { 
    Remove-Item -Path $export -Force 
}

$secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
if (Test-Path $secedt) { 
    Remove-Item -Path $secedt -Force 
}

try {
    Write-Output ("Granting SeServiceLogonRight to user account: $grantLogonAsServiceAccountName.") 
    $sid = ((New-Object System.Security.Principal.NTAccount($grantLogonAsServiceAccountName)).Translate([System.Security.Principal.SecurityIdentifier])).Value
    secedit /export /cfg $export
    $sids = (select-string $export -pattern "SeServiceLogonRight").line.Split("=").Trim()[1]
    foreach ($line in @("[Unicode]", "Unicode=yes", "[System Access]", "[Event Audit]", "[Registry Values]", "[Version]", "signature=`"`$CHICAGO$`"", "Revision=1", "[Profile Description]", "Description=GrantLogOnAsAService security template", "[Privilege Rights]", "SeServiceLogonRight = $sids,*$sid")) {
        Add-Content $import $line
    }
    
    Write-Verbose "Calling secedit..."
    secedit /import /db $secedt /cfg $import
    secedit /configure /db $secedt
    Write-Verbose "Calling gpupdate..."
    gpupdate /force
    Write-Verbose "Cleaning up temp files..."
    Remove-Item -Path $import -Force
    Remove-Item -Path $export -Force
    Remove-Item -Path $secedt -Force
    Write-Output("SeServiceLogonRight successfully granted to $grantLogonAsServiceAccountName")
}
catch {
    Write-Error "Failed to grant SeServiceLogonRight to user account: $grantLogonAsServiceAccountName."
    $error[0]
}
