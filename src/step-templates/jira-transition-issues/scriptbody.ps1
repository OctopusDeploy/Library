$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$Uri = $OctopusParameters["Jira.Transition.Url"]
$Jql = $OctopusParameters["Jira.Transition.Query"]
$Transition = $OctopusParameters["Jira.Transition.Name"]
$User = $OctopusParameters["Jira.Transition.Username"]
$Password = $OctopusParameters["Jira.Transition.Password"]

if ([string]::IsNullOrWhitespace($Uri)) {
    throw "Missing parameter value for 'Jira.Transition.Url'"
}
if ([string]::IsNullOrWhitespace($Jql)) {
    throw "Missing parameter value for 'Jira.Transition.Query'"
}
if ([string]::IsNullOrWhitespace($Transition)) {
    throw "Missing parameter value for 'Jira.Transition.Name'"
}
if ([string]::IsNullOrWhitespace($User)) {
    throw "Missing parameter value for 'Jira.Transition.Username'"
}
if ([string]::IsNullOrWhitespace($Password)) {
    throw "Missing parameter value for 'Jira.Transition.Password'"
}

function Create-Uri {
    Param (
        $BaseUri,
        $ChildUri
    )

    if ([string]::IsNullOrWhitespace($BaseUri)) {
        throw "BaseUri is null or empty!"
    }
    if ([string]::IsNullOrWhitespace($ChildUri)) {
        throw "ChildUri is null or empty!"
    }
    $CombinedUri = "$($BaseUri.TrimEnd("/"))/$($ChildUri.TrimStart("/"))"
    return New-Object -TypeName System.Uri $CombinedUri
}

function Jira-QueryApi {
    Param (
        [Uri]$Query,
        [string]$Username,
        [string]$Password
    );

    Write-Output "Querying JIRA API $($Query.AbsoluteUri)"

    # Prepare the Basic Authorization header - PSCredential doesn't seem to work
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))
    $headers = @{Authorization = ("Basic {0}" -f $base64AuthInfo) }

    # Execute the query
    Invoke-RestMethod -Uri $Query -Headers $headers
}

function Jira-ExecuteApi {
    Param (
        [Uri]$Query,
        [string]$Body,
        [string]$Username,
        [string]$Password
    );

    Write-Output "Posting JIRA API $($Query.AbsoluteUri)"

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))
    $headers = @{Authorization = ("Basic {0}" -f $base64AuthInfo) }

    Invoke-RestMethod -Uri $Query -Headers $headers -UseBasicParsing -Body $Body -Method Post -ContentType "application/json"
}

function Jira-GetTransitions {
    Param (
        [Uri]$TransitionsUri,
        [string]$Username,
        [string]$Password
    );

    $transitions = Jira-QueryApi -Query $TransitionsUri -Username $Username -Password $Password
    $transitions.transitions
}

function Jira-PostTransition {
    Param (
        [Uri]$TransitionsUri,
        [string]$Username,
        [string]$Password,
        [string]$Body
    );

    Jira-ExecuteApi -Query $TransitionsUri -Body $body -Username $Username -Password $Password
}

function Jira-TransitionTicket {
    Param (
        [Uri]$IssueUri,
        [string]$Username,
        [string]$Password,
        [string]$Transition
    );

    $query = $IssueUri.AbsoluteUri + "/transitions"
    $uri = [System.Uri] $query

    $transitions = Jira-GetTransitions -TransitionsUri $uri -Username $Username -Password $Password
    $match = $transitions | Where-Object name -eq $Transition | Select-Object -First 1
    $comment = "Status automatically updated via Octopus Deploy with release {0} of {1} to {2}" -f $OctopusParameters['Octopus.Action.Package.PackageVersion'], $OctopusParameters['Octopus.Project.Name'], $OctopusParameters['Octopus.Environment.Name'] 
    
    If ($null -ne $match) {
        $transitionId = $match.id
        $body = "{ ""update"": { ""comment"": [ { ""add"" : { ""body"" : ""$comment"" } } ] }, ""transition"": { ""id"": ""$transitionId"" } }"

        Jira-PostTransition -TransitionsUri $uri -Body $body -Username $Username -Password $Password
    }
}

function Jira-TransitionTickets {
    Param (
        [string]$BaseUri,
        [string]$Username,
        [string]$Password,
        [string]$Jql,
        [string]$Transition
    );

    try {
        # Try the newer JQL search endpoint first
        $childUri = ("/rest/api/2/search/jql?jql=" + $Jql)
        $queryUri = Create-Uri -BaseUri $BaseUri -ChildUri $childUri
        
        $json = Jira-QueryApi -Query $queryUri -Username $Username -Password $Password
        Set-Content -Path "./header.txt" -Value $json.issues
        If ($json.issues.Count -eq 0) {
            Write-Output "No issues were found that matched your query : $Jql"
            return
        }
    }
    catch {
        # Fallback to the older search endpoint if the newer one fails
        Write-Output "Falling back to older JQL search endpoint"
        $childUri = ("/rest/api/2/search?jql=" + $Jql)
        $queryUri = Create-Uri -BaseUri $BaseUri -ChildUri $childUri
        
        $json = Jira-QueryApi -Query $queryUri -Username $Username -Password $Password
        If ($json.total -eq 0) {
            Write-Output "No issues were found that matched your query : $Jql"
            return
        }
    }

    ForEach ($issue in $json.issues) {
        $issuePath = ("/rest/api/2/issue/" + $issue.id)
        $queryUri = Create-Uri -BaseUri $BaseUri -ChildUri $issuePath
        Jira-TransitionTicket -IssueUri $queryUri -Transition $Transition -Username $Username -Password $Password
    }
}

Write-Output "JIRA - Create Transition"
Write-Output "  JIRA URL   : $Uri"
Write-Output "  JIRA JQL   : $Jql"
Write-Output "  Transition : $Transition"
Write-Output "  Username   : $User"

# Some sample values:
#   $uri = "http://tempuri.org"
#   $Jql = "fixVersion = 11.3.1 AND status = Completed"
#   $Ttransition = "Deploy"
#   $User = "admin"
#   $Pass = "admin"

try {
    Jira-TransitionTickets -BaseUri $Uri -Jql $Jql -Transition $Transition -Username $User -Password $Password
}
catch {
    Write-Error "An error occurred while attempting to transition the JIRA issues: $($_.Exception)"
}