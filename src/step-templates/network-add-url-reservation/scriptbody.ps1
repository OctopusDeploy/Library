$url = $OctopusParameters['Url']
$user = $OctopusParameters['User']
$delegate = if ('True' -eq $OctopusParameters['Delegate']) { 'yes' } else { 'no'}

$delacl = "http delete urlacl url=$url"
$addacl = "http add urlacl url=$url user=""$user"" delegate=$delegate"

write-host "Removing ACL: $delacl"
$delacl | netsh | out-host

write-host "Creating ACL: $addacl"
$addacl | netsh | out-host
