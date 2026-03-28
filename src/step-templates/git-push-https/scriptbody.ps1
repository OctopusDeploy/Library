[System.Reflection.Assembly]::LoadWithPartialName("System.Web")

# A collection of functions that can be used by script steps to determine where packages installed
# by previous steps are located on the filesystem.
 
function Find-InstallLocations {
    $result = @()
    $OctopusParameters.Keys | foreach {
        if ($_.EndsWith('].Output.Package.InstallationDirectoryPath')) {
            $result += $OctopusParameters[$_]
        }
    }
    return $result
}
 
function Find-InstallLocation($stepName) {
    $result = $OctopusParameters.Keys | where {
        $_.Equals("Octopus.Action[$stepName].Output.Package.InstallationDirectoryPath",  [System.StringComparison]::OrdinalIgnoreCase)
    } | select -first 1
 
    if ($result) {
        return $OctopusParameters[$result]
    }
 
    throw "No install location found for step: $stepName"
}
 
function Find-SingleInstallLocation {
    $all = @(Find-InstallLocations)
    if ($all.Length -eq 1) {
        return $all[0]
    }
    if ($all.Length -eq 0) {
        throw "No package steps found"
    }
    throw "Multiple package steps have run; please specify a single step"
}

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
$tempDirectoryPath = join-path $tempDirectoryPath "GitPush" 
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Environment.Name']
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Project.Name']
$tempDirectoryPath = join-path $tempDirectoryPath $OctopusParameters['Octopus.Action.Name']

$stepName = $OctopusParameters['GitHttpsPackageStepName']

$stepPath = ""
if (-not [string]::IsNullOrEmpty($stepName)) {
    Write-Host "Finding path to package step: $stepName"
    $stepPath = Find-InstallLocation $stepName
} else {
    $stepPath = Find-SingleInstallLocation
}
Write-Host "Package was installed to: $stepPath"

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

# Step 2: Overwrite the contents
write-host "Synchronizing package contents with local git repository using Robocopy"
& robocopy $stepPath $tempDirectoryPath /MIR /xd ".git"
if ($lastexitcode -ge 5) {
    write-error "Unable to copy files from the package to the local cloned Git repository. See the Robocopy errors above for details."
}

# Step 3: Push the results
$deploymentName = $OctopusParameters['Octopus.Deployment.Name']
$releaseName = $OctopusParameters['Octopus.Release.Number']
$projName = $OctopusParameters['Octopus.Project.Name']

git add . -A
Test-LastExit "git add"

git diff-index --quiet HEAD
if ($lastexitcode -ne 0) {
    git commit -m "$projName release $releaseName - $deploymentName"
    Test-LastExit "git commit"
}

git push origin $branch
Test-LastExit "git push"
