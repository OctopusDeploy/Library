[System.Reflection.Assembly]::LoadWithPartialName("System.Web")
function Format-UriWithCredentials($url, $username, $password) {
    $uri = New-Object "System.Uri" $url
    
    $url = $uri.Scheme + "://"
    if (-not [string]::IsNullOrEmpty($username)) {
        $url = $url + [System.Web.HttpUtility]::UrlEncode($username)
        
        if (-not [string]::IsNullOrEmpty($password)) {
            $url = $url + ":" + [System.Web.HttpUtility]::UrlEncode($password)  
        }
        
        $url = $url + "@"    
    } elseif (-not [string]::IsNullOrEmpty($uri.UserInfo)) {
        $url = $uri.UserInfo + "@"
    }

    $url = $url + $uri.Host + $uri.PathAndQuery
    return $url
}

function Test-LastExit($cmd) {
    if ($LastExitCode -ne 0) {
        Write-Host "##octopus[stderr-error]"
        write-error "$cmd failed with exit code: $LastExitCode"
    }
}

$tempDirectoryPath = $OctopusParameters['Octopus.Tentacle.Agent.ApplicationDirectoryPath']
$tempDirectoryPath = join-path $tempDirectoryPath "GitPull" 
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Environment.Name']
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Project.Name']
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Action.Name']

Write-Host "Repository will be cloned to: $tempDirectoryPath"

# Step 1: Ensure we have the latest version of the repository
mkdir $tempDirectoryPath -ErrorAction SilentlyContinue
cd $tempDirectoryPath

Write-Host "##octopus[stderr-progress]"

git init
Test-LastExit "git init"

$url = Format-UriWithCredentials -url $OctopusParameters['GitHttpsUrl'] -username $OctopusParameters['Username'] -password $OctopusParameters['Password']

$branch = $OctopusParameters['GitHttpsBranchName']

# We might have already run before, so we need to reset the origin
git remote remove origin
git remote add origin $url
Test-LastExit "git remote add origin"

Write-Host "Fetching remote repository"
git fetch origin
Test-LastExit "git fetch origin"

Write-Host "Check out branch $branch"
git reset --hard "origin/$branch"
Test-LastExit "git reset --hard"

Set-OctopusVariable -name "RepositoryDirectory" -value $tempDirectoryPath
Write-Verbose "Directory path '$tempDirectoryPath' available in 'RepositoryDirectory' output variable"
Write-Host "Repository successfully cloned to: $tempDirectoryPath"