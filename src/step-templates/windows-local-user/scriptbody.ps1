$username = $OctopusParameters['Username']
$password = $OctopusParameters['Password']
$memberOf = $OctopusParameters['MemberOf']
$userRights = $OctopusParameters['UserRights']

# Add/Update User

$user = Get-WmiObject Win32_UserAccount -filter "LocalAccount=True AND Name='$username'"
if($user -eq $null)
{
    Write-Host "Adding user"
    net user "$username" "$password" /add /expires:never /passwordchg:no /yes
}
else
{
    Write-Host "User already exists, updating password"
    net user "$username" "$password" /expires:never /passwordchg:no
}

# Ensure password never expires

write "Ensuring password never expires"
$user = Get-WmiObject Win32_UserAccount -filter "LocalAccount=True AND Name='$username'"
$user.PasswordExpires = $false; 
$user.Put();

# Add/Update group membership

if($memberOf)
{
    $groups = $memberOf.Split(",")
    foreach($group in $groups)
    {
        $ntGroup = [ADSI]("WinNT://./$group")
        $members = $ntGroup.psbase.Invoke("Members") | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}
        if($members -contains "$username")
        {
            Write-Host "User already a member of the $group group" 
        }
        else
        {
            Write-Host "Adding to the $group group"
            net localgroup "$group" "$username" /add
        }
    }
}

# Add/Update user rights assignment

if($userRights)
{
    $userRightsArr = $userRights.Split(",")
    foreach($userRight in $userRightsArr)
    {
        Write-Host "Granting $userRight right"
        & "ntrights" +r $userRight -u "$username"
    }
}
