[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$formattedVersionNumber = [string]::Format("v{0}", $versionNumber)
$isDraft = [bool]::Parse($draft)
$isPrerelease = [bool]::Parse($preRelease)

$releaseData = @{
    tag_name = $formattedVersionNumber;
    target_commitish = $commitId;
    name = $formattedVersionNumber;
    body = $releaseNotes;
    draft = $isDraft;
    prerelease = $isPrerelease;
}
$json = (ConvertTo-Json $releaseData -Compress)
$releaseParams = @{
    Uri = "https://api.github.com/repos/$gitHubUsername/$gitHubRepository/releases";
    Method = 'POST';
    Headers = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes($gitHubApiKey + ":x-oauth-basic")
        );
    }
    ContentType = 'application/json; charset=utf-8';
    Body = [System.Text.Encoding]::UTF8.GetBytes($json)
}

Write-Host "Creating release $formattedVersionNumber for $commitId."
$result = Invoke-RestMethod @releaseParams

Write-Host "Release successfully created."
$result