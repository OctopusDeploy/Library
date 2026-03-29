#require version 3.0

param (
    [System.Uri]$Uri,
    [string]$Jql,
    [string]$Version,
    [string]$User,
    [string]$Password,
    [string]$ProjectKey    
)

$ErrorActionPreference = "Stop"
$AllProtocols = [System.Net.SecurityProtocolType]'Tls,Tls11,Tls12'
[Net.ServicePointManager]::SecurityProtocol = $AllProtocols

function Get-Param($Name, [switch]$Required, $Default) {
    $result = $null

    if ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
    }

    if ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue    
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    if ($result -eq $null) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    return $result
}

function Jira-QueryApi
{
    Param (
        [Uri]$Query,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Querying JIRA API $($Query.AbsoluteUri)"

    # Prepare the Basic Authorization header - PSCredential doesn't seem to work
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

    # Execute the query
    Invoke-RestMethod -Uri $Query -Headers $headers
}

function Jira-ExecuteApi
{
    Param (
        [Uri]$Query,
        [string]$Body,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Updating ticket : $($Query.AbsoluteUri)"

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    Invoke-RestMethod -Uri $Query -Headers $headers -UseBasicParsing -Body $Body -Method Put -ContentType "application/json"
}

function Jira-CreateVersion
{
    Param (
        [Uri]$Query,
        [string]$Body,
        [string]$Username,
        [string]$Password
    );

    Write-Host "Creating a version $($Query.AbsoluteUri)"

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    Invoke-RestMethod -Uri $Query -Headers $headers -UseBasicParsing -Body $Body -Method Post -ContentType "application/json"
}

function Jira-GetVersions
{
    Param (
        [Uri]$VersionsUri,
        [string]$Username,
        [string]$Password
    );

    $versions = Jira-QueryApi -Query $VersionsUri -Username $Username -Password $Password    
    $versions
}

function Jira-PostUpdate
{
    Param (
        [Uri]$IssueUri,
        [string]$Username,
        [string]$Password,
        [string]$Body
    );

    Jira-ExecuteApi -Query $IssueUri -Body $body -Username $Username -Password $Password
}

function Jira-UpdateTicket
{
    Param (
    	[Uri]$BaseUri,
        [Uri]$IssueUri,
        [string]$Username,
        [string]$Password,
        [string]$Version,
        [string]$ProjectKey,
        [System.Uri]$GetVersionsAPIURL,
        [System.Uri]$CreateVersionAPIURL          
    );

    $query = $IssueUri.AbsoluteUri
    $uri = [System.Uri] $query
	
    $versionuri = $GetVersionsAPIURL
    $createversionuri = $CreateVersionAPIURL
       
    $versions = Jira-GetVersions -VersionsUri $versionuri -Username $Username -Password $Password
               
    $match = $versions | Where name -eq $Version | Select -First 1   
    
    If ($match -ne $null)
    {                      
		$body = "{ ""update"" : { ""fixVersions"" : [ {""add"" : {""name"" : ""$Version""} } ] } }"
        Jira-PostUpdate -IssueUri $uri -Body $body -Username $Username -Password $Password      
    }    
    else
    {
    	$body = "{ ""name"": ""$Version"",	""project"": ""$ProjectKey""}"
     	Jira-CreateVersion -Query $createversionuri -Body $body -Username $Username -Password $Password
        
        $body = "{ ""update"" : { ""fixVersions"" : [ {""add"" : {""name"" : ""$Version""} } ] } }"
        Jira-PostUpdate -IssueUri $uri -Body $body -Username $Username -Password $Password  
    }
}

function Jira-UpdateTickets
{
    Param (
        [Uri]$BaseUri,
        [string]$Username,
        [string]$Password,
        [string]$Jql,
        [string]$Version,
        [string]$ProjectKey,
        [System.Uri]$GetVersionsAPIURL,
        [System.Uri]$CreateVersionAPIURL        
    );

    $api = New-Object -TypeName System.Uri -ArgumentList $BaseUri, ("/rest/api/2/search?jql=" + $Jql)
    $json = Jira-QueryApi -Query $api -Username $Username -Password $Password

    If ($json.total -eq 0)
    {
        Write-Output "No issues were found that matched your query : $Jql"
    }
    Else
    {
        ForEach ($issue in $json.issues)
        {
            Jira-UpdateTicket -BaseUri $BaseUri -IssueUri $issue.self -Version $Version -Username $Username -Password $Password -ProjectKey $ProjectKey -GetVersionsAPIURL $GetVersionsAPIURL -CreateVersionAPIURL $CreateVersionAPIURL
        }
    }
}

& {
    param(
        [System.Uri]$Uri,
        [string]$Jql,
        [string]$Version,
        [string]$User,
        [string]$Password,
        [string]$ProjectKey,
        [System.Uri]$GetVersionsAPIURL,
        [System.Uri]$CreateVersionAPIURL
    )

    Write-Host "JIRA - Update Version Number"
    Write-Host " Updating Fix Versions to : $Version"

    try     {
        Jira-UpdateTickets -BaseUri $Uri -Jql $Jql -Version $Version -Username $User -Password $Password -ProjectKey $ProjectKey -GetVersionsAPIURL $GetVersionsAPIURL -CreateVersionAPIURL $CreateVersionAPIURL
    } catch {
        Write-Host -ForegroundColor Red "An error occurred while attempting to update Fix Versions in JIRA issues"
        Write-Host -ForegroundColor Red $_.Exception | Format-List -Force
    }
} `
(Get-Param "Jira.Version.Url" -Required) `
(Get-Param "Jira.Version.Query" -Required) `
(Get-Param "Jira.Version.Name" -Required) `
(Get-Param "Jira.Version.Username" -Required) `
(Get-Param "Jira.Version.Password" -Required) `
(Get-Param "Jira.Version.ProjectKey" -Required) `
(Get-Param "Jira.Version.GetVersionsAPIURL" -Required) `
(Get-Param "Jira.Version.CreateVersionAPIURL" -Required)
