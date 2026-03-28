# There have been reported issues when using the default JSON parser with Invoke-RestMethod
# on PowerShell 5. So we are going to pull in a different assembly to do the parsing for us.
# This parser appears to be more reliable.
[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
$jsonParser = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
$jsonParser.MaxJsonLength = 104857600 #100mb as bytes, default is 2mb

function Write-AnsibleLine([String] $text) {
    # split text at ESC-char
    $ansi_colors = @(
        '[0;30m' #= @{ fg = ConsoleColor.Black }
        '[0;31m' #= @{ fg = ConsoleColor.DarkRed }
        '[0;32m' #= @{ fg = ConsoleColor.DarkGreen }
        '[0;33m' #= @{ fg = ConsoleColor.DarkYellow }
        '[0;34m' #= @{ fg = ConsoleColor.DarkBlue }
        '[0;35m' #= @{ fg = ConsoleColor.DarkMagenta }
        '[0;36m' #= @{ fg = ConsoleColor.DarkCyan }
        '[0;37m' #= @{ fg = ConsoleColor.White }
        '[0m' #= @{ fg = $null; bg = $null }
        '[1;35m' #= Magent (ansible warnings)
        '[30;1m' #= @{ fg = ConsoleColor.Grey }
        '[31;1m' #= @{ fg = ConsoleColor.Red }
        '[32;1m' #= @{ fg = ConsoleColor.Green }
        '[33;1m' #= @{ fg = ConsoleColor.Yellow }
        '[34;1m' #= @{ fg = ConsoleColor.Blue }
        '[35;1m' #= @{ fg = ConsoleColor.Magenta }
        '[36;1m' #= @{ fg = ConsoleColor.Cyan }
        '[37;1m' #= @{ fg = ConsoleColor.White }
        '[0;40m' #= @{ bg = ConsoleColor.Black }
        '[0;41m' #= @{ bg = ConsoleColor.DarkRed }
        '[0;42m' #= @{ bg = ConsoleColor.DarkGreen }
        '[0;43m' #= @{ bg = ConsoleColor.DarkYellow }
        '[0;44m' #= @{ bg = ConsoleColor.DarkBlue }
        '[0;45m' #= @{ bg = ConsoleColor.DarkMagenta }
        '[0;46m' #= @{ bg = ConsoleColor.DarkCyan }
        '[0;47m' #= @{ bg = ConsoleColor.White }
        '[40;1m' #= @{ bg = ConsoleColor.DarkGrey }
        '[41;1m' #= @{ bg = ConsoleColor.Red }
        '[42;1m' #= @{ bg = ConsoleColor.Green }
        '[43;1m' #= @{ bg = ConsoleColor.Yellow }
        '[44;1m' #= @{ bg = ConsoleColor.Blue }
        '[45;1m' #= @{ bg = ConsoleColor.Magenta }
        '[46;1m' #= @{ bg = ConsoleColor.Cyan }
        '[47;1m' #= @{ bg = ConsoleColor.White }
    )
    foreach ($segment in $text.split([char] 27)) {
        foreach($code in $ansi_colors) {
            if($segment.startswith($code)) {
                $segment = $segment.replace($code, "")
            }
        }
        Write-Host -NoNewline $segment
    }
    Write-Host ""
}
 
 
Function Resolve-Tower-Asset{
    Param($Name, $Url)
    Process {
        if($script:Verbose) { Write-Host "Resolving name $Name" }
        $object = $null
        if($Name -match '^[0-9]+$') {
            if($script:Verbose) { Write-Host "Using $Name as ID as its an int already" }
            $url = "$Url/$Name/"
            try { $object = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object]) }
            catch {
                Write-Host "Error when resolving ID for $Name"
                Write-Host $_
                return $null
            }
        } else {
           if($script:Verbose) { Write-Host "Looking up ID of name $Name" }
            $url = "$Url/?name=$Name"
            try { $response = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object]) }
            catch {
                Write-Host "Unable to resolve name $Name"
                Write-Host $_
                return $null
            }
            if($response.count -eq 0) {
                Write-Host "Got no results when trying to get ID for $Name"
                return $null
            } elseif($response.count -ne 1) {
                Write-Host "Did not get a unique job ID for job name $Name"
                return $null
            }
            if($script:Verbose) { Write-Host "Resolved to ID $($response.results[0].id)" }
            $object = $response.results[0]
        }
        return $object
    }
}


function Get-Auth-Headers {
    # If we did not get a TowerOAuthToken or a (TowerUsername and TowerPassword) then we can't even try to auth
    if(-not (($TowerUsername -and $TowerPassword) -or $TowerOAuthToken)) {
        Fail-Step "Please pass an OAuth Token and or a Username/Password to authenticate to Tower with"
    }

    if($TowerOAuthToken) {
        if($verbose) { Write-Host "Testing OAuth token" }
        $token_headers = @{ "Authorization" = "Bearer $TowerOAuthToken" }
        try {
            # We have to assign it to something or we get a line in the output
            $junk = $jsonParser.Deserialize((Invoke-WebRequest "$api_base/job_templates/?name=Octopus" -Method GET -Headers $token_headers -UseBasicParsing), [System.Object])
            $script:auth_headers = $token_headers
            return
        } catch {
            Write-Host "Unable to authenticate to the Tower server with OAuth token"
            Write-Host $_
        }
    }

    if(-not ($TowerUsername -and $TowerPassword)) {
        Fail-Step "No username/password to fall back on"
    }

    if($verbose) { Write-Host "Testing basic auth" }
    $pair = "${TowerUsername}:${TowerPassword}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $basic_auth_value = "Basic $base64"
    $headers = @{ "Authorization" = $basic_auth_value }
    try {
        # We have to assign it to something or we get a line in the output
        $junk = $jsonParser.Deserialize((Invoke-WebRequest "$api_base/job_templates/?name=Octopus" -Method GET -Headers $headers -UseBasicParsing), [System.Object])
        $script:auth_headers = $headers
    } catch {
        Write-Host $_
        Fail-Step "Username password combination failed to work"
    }

    if ($script:Verbose) { Write-Host "Attempting to get authentcation Token for $TowerUsername" }
    $body = @{
        username = $TowerUsername
        password = $TowerPassword
    } | ConvertTo-Json
    $url = "$api_base/authtoken/"
    try {
        $auth_token = $jsonParser.Deserialize((Invoke-WebRequest $url -Method POST -Headers $headers -Body $body -ContentType "application/json" -UseBasicParsing), [System.Object])
        $script:auth_headers = @{ Authorization = "Token $($auth_token.token)" }
        return
    } catch {
        if($_.Exception.Response.StatusCode -eq 404) {
            Write-Host(">>> Server does not support authtoken, try using an OAuth Token")
            Write-Host(">>> Defaulting to perpetual basic auth. This can be slow for authentication with external sources")
            return
        } else {
            Write-Host $_
            Fail-Step "Unable to authenticate to the Tower server for Auth token"
        }
    }
}

function Watch-Job-Complete {
    Param($Id)
    Process {
        $last_log_id = 0
        while($True) {
            # First log any events if the user wants them
            if($TowerImportLogs) {
                $url = "$api_base/jobs/$Id/job_events/?id__gt=$last_log_id"
                $response = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object])
                foreach($result in $response.results) {
                    if($last_log_id -lt $result.id) { $last_log_id = $result.id }
                    if($result.event_data -and $result.event_data.res -and $result.event_data.res.output) {
                        foreach($line in $result.event_data.res.output) {
                            Write-AnsibleLine($line)
                        }
                    } else {
                        $line = $result.stdout
                        Write-AnsibleLine($line)
                    }
                }
            }
 
            # Now check the status of the job
            $url = "$api_base/jobs/$Id/"
            $response = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object])
            if($response.finished) {
               $response.failed
               return
            } else {
               Start-Sleep -s $SecondsBetweenChecks
            }
        }
    }
}
 
function Watch-Workflow-Complete {
    Param($Id)
    Process {
        $workflow_node_id = 0
        while($True) {
            # Check to see if there are any jobs we need to follow
            $url = "$tower_base/api/v2/workflow_jobs/$Id/workflow_nodes/?id__gt=$workflow_node_id"
            $response = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object])

            # If there are no nodes whose ID is > the last one we looked at we can see if we are complete
            if($response.count -eq 0) {
                $url = "$tower_base/api/v2/workflow_jobs/$Id/"
                $response = $jsonParser.Deserialize((Invoke-WebRequest $url -Method GET -Headers $script:auth_headers -UseBasicParsing), [System.Object])
                if($response.finished) {
                    $response.failed
                    return
                } else {
                    Start-Sleep -s $SecondsBetweenChecks
                }
            } else {
                foreach($result in $response.results) {
                    if($result.summary_fields.unified_job_template.unified_job_type -eq 'job') {
                        $job_id = $result.summary_fields.job.id
                        if(-not $job_id) {
                            # This is a job but it hasn't started yet, lets sleep and try again
                            Start-Sleep -s $SecondsBetweenChecks
                            break
                        }
                        if($script:Verbose) { Write-Host "Monitoring job $($result.summary_fields.job.name)" }
                        # We have to trap the return of Watch-Job-Complete
                        $junk = Watch-Job-Complete -Id $job_id
                    } else {
                        if($script:Verbose) { Write-Host "Not pulling logs for node $($result.id) which is a $($result.summary_fields.unified_job_template.unified_job_type)" }
                    }
                    $workflow_node_id = $result.id
                }
            }
        }
    }
}



##### Main Body




# Check that we got a TowerJobTemplate, without one we can't do anything
if(-not ($TowerJobType -eq "job" -or $TowerJobType -eq "workflow")) { Fail-Stop "The job type must be either job or workflow" }
if($TowerJobTemplate -eq $null -or $TowerJobTemplate -eq "") { Fail-Step "A Job Name needs to be specified" }
if($TowerJobTags -eq "") { $TowerJobTags = $null }
if($TowerExtraVars -eq "") { $TowerExtraVars = $null }
if($TowerLimit -eq "") { $TowerLimit = $null }
if($TowerInventory -eq "") { $TowerInventory = $null }
if($TowerCredential -eq "") { $Credential = $null }
if($TowerImportLogs -and $TowerImportLogs -eq "True") { $TowerImportLogs = $True } else { $TowerImportLogs = $False }
if($TowerVerbose -and $TowerVerbose -eq "True") { $Verbose = $True} else { $Verbose = $False }
if($TowerSecondsBetweenChecks) {
    try { $SecondsBetweenChecks = [int]$TowerSecondsBetweenChecks }
    catch {
        write-Host "Failed to parse $TowerSecondsBetweenChecks as integer, defaulting to 3"
        $SecondsBetweenChecks = 3
    }
} else {
    $SecondsBetweenChecks = 3
}
if($TowerTimeLimitInSeconds) {
    try { $TowerTimeLimitInSeconds = [int]$TowerTimeLimitInSeconds }
    catch {
        write-Host "Failed to parse $TowerTimeLimitInSeconds as integer, defaulting to 600"
        $TowerTimeLimitInSeconds = 600
    }
} else {
    $TowerTimeLimitInSeconds = 600
}
if($TowerIgnoreCert -and $TowerIgnoreCert -eq "True") {
    # Joyfully borrowed from Markus Kraus' post on
    # https://blog.ukotic.net/2017/08/15/could-not-establish-trust-relationship-for-the-ssltls-invoke-webrequest/
    if(-not([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
        Add-Type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    #endregion
}
 
if ($Verbose) { Write-Host "Beginning Ansible Tower Run on $TowerServer" }
$tower_url = [System.Uri]$TowerServer
if(-not $tower_url.Scheme) { $tower_url = [System.Uri]"https://$TowerServer" }
$tower_base = $tower_url.ToString().TrimEnd("/")
$api_base = "${tower_base}/api/v2"
 
# First handle authentication
#   If we have a TowerOAuthToken try using that
#   Else get an authentication token if we have a user name/password
$auth_headers = @{'initial' = 'Data'}
Get-Auth-Headers
 
 
# If the TowerJobTemplate is actually an ID we can just use that.
# If not we need to lookup the ID from the name
if($TowerJobType -eq 'job') {
    $template = Resolve-Tower-Asset -Name $TowerJobTemplate -Url "$api_base/job_templates"
} else {
    $template = Resolve-Tower-Asset -Name $TowerJobTemplate -Url "$api_base/workflow_job_templates"
}
if($template -eq $null) { Fail-Step "Unable to resolve the job name" }
 
if($TowerExtraVars -ne $null -and $TowerExtraVars -ne '---' -and $template.ask_variables_on_launch -eq $False) {
    Write-Warning "Extra variables defined but prompt for variables on launch is not set in tower job"
}
if($TowerLimit -ne $null -and $template.ask_limit_on_launch -eq $False) {
    Write-Warning "Limit defined but prompt for limit on launch is not set in tower job"
}
if($TowerJobTags -ne $null -and $template.ask_tags_on_launch -eq $False) {
    Write-Warning "Job Tags defined but prompt for tags on launch is not set in tower job"
}
if($TowerInventory -ne $null -and $template.ask_inventory_on_launch -eq $False) {
    Write-Warning "Inventory defined but prompt for inventory on launch is not set in tower job"
}
if($TowerCredential -ne $null -and $template.ask_credential_on_launch -eq $False) {
    Write-Warning "Credential defined but prompt for credential on launch is not set in tower job"
}
<#
// Here are some more options we may want to use/check someday
//    "ask_diff_mode_on_launch": false,
//    "ask_skip_tags_on_launch": false,
//    "ask_job_type_on_launch": false,
//    "ask_verbosity_on_launch": false,
#>
 
 
# Construct the post body
$post_body = @{}
if($TowerInventory -ne $null) {
    $inventory = Resolve-Tower-Asset -Name $TowerInventory -Url "$api_base/inventories"
    if($inventory -eq $null) { Fail-Step("Unable to resolve inventory") }
    $post_body.inventory = $inventory.id
}
 
if($TowerCredential -ne $null) {
    $credential = Resolve-Tower-Asset -Name $TowerCredential -Url "$api_base/credentials"
    if($credential -eq $null) { Fail-Step("Unable to resolve credential") }
    $post_body.credentials = @($credential.id)
}
if($TowerLimit -ne $null) { $post_body.limit = $TowerLimit }
if($TowerJobTags -ne $null) { $post_body.job_tags = $TowerJobTags }
# Older versions of Tower did not like receiveing "---" as extra vars.
if($TowerExtraVars -ne $null -and $TowerExtraVars -ne "---") { $post_body.extra_vars = $TowerExtraVars }
 
if($Verbose) { Write-Host "Requesting tower to run $TowerJobTemplate" }
if($TowerJobType -eq 'job') {
    $url = "$api_base/job_templates/$($template.id)/launch/"
} else {
    $url = "$api_base/workflow_job_templates/$($template.id)/launch/"
}
try {
    $response = Invoke-WebRequest -Uri $url -Method POST -Headers $auth_headers -Body ($post_body | ConvertTo-JSON) -ContentType "application/json" -UseBasicParsing
} catch {
    Write-Host "Failed to make request to invoke job"
    $initialError = $_
    try {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        <#
            Some stuff that we might want to catch includes:
                {"extra_vars":["Must be valid JSON or YAML."]}
                {"variables_needed_to_start":["'my_var' value missing"]}
                {"credential":["Invalid pk \"999999\" - object does not exist."]}
                {"inventory":["Invalid pk \"99999999\" - object does not exist."]}
            The last two we don't really care about because we should never hit them
        #>
        if($body.extra_vars -ne $null) {
            Fail-Step "Failed to launch job: extra vars must be vailid JSON or YAML."
        } elseif($body.variables_needed_to_start -ne $null) {
            Fail-Step "Failed to launch job: $($body.variables_needed_to_start)"
        } else {
            Write-Host $body
            Fail-Step "Failed to launch job for an unknown reason"
        }
    } catch {
        Write-Host "Failed to get response body from request"
        Write-Host $initialError
    }
}


$template_id = $($response | ConvertFrom-Json).id
Write-Host("Best Guess Job URL: $tower_base/#/$($TowerJobType)s/$template_id")
 
# For whatever reason, this never fires
#$timer = new-object System.Timers.Timer
#$timer.Interval = 500 #1000 * $TowerTimeLimitInSeconds
#$action = { Fail-Step "Timed out waiting for Tower to complete tempate run. Template may still be running in Tower." }
#$tower_timer = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action $action
#$timer.AutoReset = $False
#$timer.Enabled = $True

if($TowerJobType -eq 'job') {
    $failed = Watch-Job-Complete -Id $template_id
} else {
    $failed = Watch-Workflow-Complete -Id $template_id
}

#$timer.Stop()
#Unregister-Event $tower_timer.Name


if($failed) {
    Fail-Step "Job Failed"
} else {
    Write-Host "Job Succeeded"
}
