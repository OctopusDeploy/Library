#fix for bug with encode and powershell 4
#https://stackoverflow.com/questions/43129163/powershell-invoke-webrequest-to-a-url-with-literal-2f-in-it
function fixUri($uri){
  $UnEscapeDotsAndSlashes = 0x2000000;
  $SimpleUserSyntax = 0x20000;

  $type = $uri.GetType();
  $fieldInfo = $type.GetField("m_Syntax", ([System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic));

  $uriParser = $fieldInfo.GetValue($uri);
  $typeUriParser = $uriParser.GetType().BaseType;
  $fieldInfo = $typeUriParser.GetField("m_Flags", ([System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::FlattenHierarchy));
  $uriSyntaxFlags = $fieldInfo.GetValue($uriParser);

  $uriSyntaxFlags = $uriSyntaxFlags -band (-bnot $UnEscapeDotsAndSlashes);
  $uriSyntaxFlags = $uriSyntaxFlags -band (-bnot $SimpleUserSyntax);
  $fieldInfo.SetValue($uriParser, $uriSyntaxFlags);
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Web

$projectIdOrProjectPathEncoded = [System.Web.HttpUtility]::UrlEncode($projectIdOrProjectPath) 
$messageEncoded = [System.Web.HttpUtility]::UrlEncode($message) 
$releaseDescriptionEncoded = [System.Web.HttpUtility]::UrlEncode($releaseDescription) 

$getTagUri = New-Object System.Uri "$gitlabUrl/api/v4/projects/$projectIdOrProjectPathEncoded/repository/tags?tag_name=$tagName"
fixUri $getTagUri
$getTagRequest = @{
    Uri = $getTagUri;
    Method = 'GET';
    Headers = @{'PRIVATE-TOKEN' = $personalAccessToken; }
    ContentType = 'application/json';
}

"Checking if tag $tagName exists."
try {
    $resultTag = Invoke-RestMethod @getTagRequest
    Write-Host "Tag info received."
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "Error while tag info receive."
    $_.Exception | Format-List -Force
    throw
}
if ($resultTag.name -eq $tagName) {
    Write-Host "Tag already exists, skip creation"
    exit
}

$createTagUri = New-Object System.Uri "$gitlabUrl/api/v4/projects/$projectIdOrProjectPathEncoded/repository/tags?tag_name=$tagName&ref=$vcsReference&message=$messageEncoded&release_description=$releaseDescriptionEncoded"
fixUri $createTagUri

$createTagRequest = @{
    Uri = $createTagUri;
    Method = 'POST';
    Headers = @{'PRIVATE-TOKEN' = $personalAccessToken; }
    ContentType = 'application/json';
}

"Creating tag $tagName for $vcsReference."

$createTagRequestLines = $createTagRequest | Out-String -Width 1000
$createTagRequestHeaderLines = $createTagRequest.Headers | Out-String -Width 1000
Write-Host "Request is $createTagRequestLines"
Write-Host "Headers is $createTagRequestHeaderLines"

try {
    $result = Invoke-RestMethod @createTagRequest
    Write-Host "Tag successfully created."
}
catch {
    Write-Host "Error while tag creating."
    $_.Exception | Format-List -Force
    throw
}


$result