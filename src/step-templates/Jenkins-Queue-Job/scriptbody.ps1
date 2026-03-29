$jenkinsServer = $OctopusParameters['jqj_JenkinsServer'] 
$jenkinsUserName = $OctopusParameters['jqj_JenkinsUserName']
$jenkinsUserPassword = $OctopusParameters['jqj_JenkinsUserPasword']
$jobURL = $jenkinsServer + $OctopusParameters['jqj_JobUrl']
$failBuild = [System.Convert]::ToBoolean($OctopusParameters['jqj_FailBuild'])
$jobTimeout = $OctopusParameters['jqj_JobTimeout']
$buildParam = $OctopusParameters['jqj_BuildParam']
$checkIntervals = $OctopusParameters['jqj_checkInterval']
$fetchBuildWait = $OctopusParameters['jqj_FetchBuildWait']
$fetchBuildLimit = $OctopusParameters['jqj_FetchBuildLimit']
$waitForComplete = $OctopusParameters['jqj_WaitForComplete']
$attachBuildLog = ([System.Convert]::ToBoolean($OctopusParameters['jqj_AttachBuildLog']))

$jobUrlWithParams = "$jobURL$buildParam"

Write-Host "job url: " $jobUrlWithParams 

function Get-JenkinsAuth
{
    $params = @{}
    if (![string]::IsNullOrWhiteSpace($jenkinsUserName)) {
        $securePwd = ConvertTo-SecureString $jenkinsUserPassword -AsPlainText -Force 
        $credential = New-Object System.Management.Automation.PSCredential ($jenkinsUserName, $securePwd) 
        $head = @{"Authorization" = "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jenkinsUserName + ":" + $jenkinsUserPassword ))}
        $params = @{
            Headers = $head;
            Credential = $credential;
            ContentType = "text/plain";
        }
    }

    # If your Jenkins uses the "Prevent Cross Site Request Forgery exploits" security option (which it should), 
    # when you make a POST request, you have to send a CSRF protection token as an HTTP request header.
    # https://wiki.jenkins.io/display/JENKINS/Remote+access+API
    try {
        $tokenUrl = $jenkinsServer + "crumbIssuer/api/json?tree=crumbRequestField,crumb"
        $crumbResult = Invoke-WebRequest -Uri $tokenUrl -Method Get @params -UseBasicParsing | ConvertFrom-Json
        Write-Host "CSRF protection is enabled, adding CSRF token to request headers"
        $params.Headers += @{$crumbResult.crumbRequestField = $crumbResult.crumb}
    } catch {
        Write-Host "Failed to get CSRF token, CSRF may not be enabled"
        Write-Host $Error[0]
    }
    return $params
}

try {
    Write-Host "Fetching Jenkins auth params"
    $authParams = Get-JenkinsAuth

    Write-Host "Start the build"
    $returned = Invoke-WebRequest -Uri $jobUrlWithParams  -Method Post -UseBasicParsing @authParams
    Write-Host "Job URL Link: $($returned.Headers['Location'])"
    $jobResult = "$($returned.Headers['Location'])/api/json"
    $response = Invoke-RestMethod -Uri $jobResult -Method Get @authParams
    $buildUrl = $Response.executable.url
    $result = ""
    $c = 0
    while (($null -eq $buildUrl -or $buildUrl -eq "") -and ($c -lt $fetchBuildLimit) ) {
        $c += 1
        $response = Invoke-RestMethod -Uri $jobResult -Method Get @authParams
        $buildUrl = $Response.executable.url
        Start-Sleep -s $fetchBuildWait
    }
    Write-Host "Build Number is: $($Response.executable.number)"
    #Write-Host "Job URL Is: $($buildUrl)"
    Write-Highlight "Job URL Is: [$($buildUrl)]($($buildUrl))"
    $buildResult = "$buildUrl/api/json?tree=result,number,building"
        
    $isBuilding = "True"
       
    if ($waitForComplete -eq "True")
    {
      while ($isBuilding -eq "True") {       
          Write-Host "waiting $checkIntervals secs for build to complete"
          Start-Sleep -s $checkIntervals
          $retyJobStatus = Invoke-RestMethod -Uri $buildResult -Method Get @authParams

          $isBuilding = $retyJobStatus[0].building
          $result = $retyJobStatus[0].result
          $buildNumber = $retyJobStatus[0].number
          
          Write-Host "Retry Job Status: " $result " BuildNumber: "  $buildNumber  " IsBuilding: "  $isBuilding 
      }

        # Get log from Jenkins
        $buildLog = (Invoke-WebRequest -Uri "$($buildUrl)/logText/progressiveText?start=0"  -Method Post -UseBasicParsing @authParams)

        Write-Host "$buildLog"

        # Check to see if the log needs to be attached
        if ($attachBuildLog)
        {
           # Send the build log to a file
          Write-Host "Getting log file ..."
          Set-Content -Path "$PWD/#{Octopus.Step.Name}.log" -Value $buildLog
  
          # Attach build log as artifact
          Write-Host "Attaching log file as artifact ..."
          New-OctopusArtifact -Path "$PWD/#{Octopus.Step.Name}.log" -Name "#{Octopus.Step.Name}.log"       
        }
    }
    else
    {
    
      $i = 0
      Write-Host "Estimate Job Duration: " $jobTimeout
      while ($isBuilding -eq "True" -and $i -lt $jobTimeout) {       
          $i += 5
          Write-Host "waiting $checkIntervals secs for build to complete"
          Start-Sleep -s $checkIntervals
          $retyJobStatus = Invoke-RestMethod -Uri $buildResult -Method Get @authParams

          $isBuilding = $retyJobStatus[0].building
          $result = $retyJobStatus[0].result
          $buildNumber = $retyJobStatus[0].number
          Write-Host "Retry Job Status: " $result " BuildNumber: "  $buildNumber  " IsBuilding: "  $isBuilding 
      }     
    }


     
    if ($failBuild) {
        if ($result -ne "SUCCESS") {
            if (![string]::IsNullOrWhitespace($result))
            {
              Write-Host "Build ended with status: $result"
            }
            else
            {
              Write-Host "BUILD FAILURE: build status could not be obtained."
            }
            exit 1
        }
    }
  else
  {
    if ([string]::IsNullOrWhitespace($result))
    {
      Write-Warning "Time-out expired before a status was returned."
    }
    else
    {
      Write-host "Process ended with status: $result."
    }
  }
}
catch {
    Write-Host "Exception in jenkins job: $($_.Exception.Message)"
    exit 1
}



