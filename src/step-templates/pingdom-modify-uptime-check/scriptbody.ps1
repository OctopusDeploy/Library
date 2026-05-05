# Ref: https://www.pingdom.com/resources/api#MethodModify+Check

Function Get-Parameter() {
    Param(
        [parameter(Mandatory=$true)]
        [string]$Name, 
        [switch]$Required, 
        $Default, 
        [switch]$FailOnValidate
    )

    $result = $null
    $errMessage = [string]::Empty

    If ($OctopusParameters -ne $null) {
        $result = $OctopusParameters[$Name]
        Write-Host ("Octopus parameter value for " + $Name + ": " + $result)
    }

    If ($result -eq $null) {
        $variable = Get-Variable $Name -EA SilentlyContinue
        if ($variable -ne $null) {
            $result = $variable.Value
        }
    }

    If ($result -eq $null -or [string]::IsNullOrEmpty($result)) {
        If ($Required) {
            $errMessage = "Missing value for $Name"
        } ElseIf (-Not $Default -eq $null) {
            Write-Host ("Default value: " + $Default)
            $result = $Default
        }
    }

    If (-Not [string]::IsNullOrEmpty($errMessage)) {
        If ($FailOnValidate) {
            Throw $errMessage
        } Else {
            Write-Warning $errMessage
        }
    }

    return $result
}

& {
    Write-Host "Start PingdomModifyUptimeCheck"

    Add-Type -AssemblyName System.Web

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $throwErrorWhenFailed = [System.Convert]::ToBoolean([string](Get-Parameter -Name "Pingdom.ThrowErrorWhenFailed" -Default "False"))

    $pingdomUsername = [string] (Get-Parameter -Name "Pingdom.Username" -Required -FailOnValidate:$throwErrorWhenFailed)
    $pingdomPassword = [string] (Get-Parameter -Name "Pingdom.Password" -Required -FailOnValidate:$throwErrorWhenFailed)
    $pingdomAppKey = [string] (Get-Parameter -Name "Pingdom.AppKey" -Required -FailOnValidate:$throwErrorWhenFailed)

    $pingdomCheckId = [string] (Get-Parameter -Name "Pingdom.CheckId" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckPaused = [string] (Get-Parameter -Name "Pingdom.CheckPaused" -Default "False" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckName = [string] (Get-Parameter -Name "Pingdom.CheckName" -Required -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckTarget = [string] (Get-Parameter -Name "Pingdom.CheckTarget" -Required -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckIntervalMinutes = [System.Nullable[int]] (Get-Parameter -Name "Pingdom.CheckIntervalMinutes" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckContactIds = [string] (Get-Parameter -Name "Pingdom.CheckContactIds" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckSendNotificationWhenDown = [System.Nullable[int]] (Get-Parameter -Name "Pingdom.CheckSendNotificationWhenDown" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckNotifyAgainEvery = [System.Nullable[int]] (Get-Parameter -Name "Pingdom.CheckNotifyAgainEvery" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckNotifyWhenBackUp = [string](Get-Parameter -Name "Pingdom.CheckNotifyWhenBackUp" -Default "True" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckTags = [string] (Get-Parameter -Name "Pingdom.CheckTags" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckHttpUrl = [string] (Get-Parameter -Name "Pingdom.CheckHttpUrl" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckHttpEncryptionEnabled = [string](Get-Parameter -Name "Pingdom.CheckHttpEncryptionEnabled" -Default "False" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckHttpTargetPort = [System.Nullable[int]] (Get-Parameter -Name "Pingdom.CheckHttpTargetPort" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckAuth = [string] (Get-Parameter -Name "Pingdom.CheckAuth" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckShouldContain = [string] (Get-Parameter -Name "Pingdom.CheckShouldContain" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckShouldNotContain = [string] (Get-Parameter -Name "Pingdom.CheckShouldNotContain" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckPostData = [string] (Get-Parameter -Name "Pingdom.CheckPostData" -FailOnValidate:$throwErrorWhenFailed)
    $pingdomCheckIntegrationIds = [string] (Get-Parameter -Name "Pingdom.CheckIntegrationIds" -FailOnValidate:$throwErrorWhenFailed)

    $apiVersion = "2.1"
    $url = "https://api.pingdom.com/api/{0}/checks" -f $apiVersion
    $securePassword = ConvertTo-SecureString $pingdomPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($pingdomUsername, $securePassword)
    $headers = @{ 
        "App-Key" = $pingdomAppKey
    }

    If ([string]::IsNullOrEmpty($pingdomCheckId) -and [string]::IsNullOrEmpty($pingdomCheckName)) {
        $errMessage = "Please specify CheckId or CheckName!"
        If($throwErrorWhenFailed -eq $true) {
            Write-Error $errMessage
        }
        Else {
            Write-Warning $errMessage
        }
        Exit
    } 
    
    # Find check id by name

    If (-Not [string]::IsNullOrEmpty($pingdomCheckName)) {
        Write-Host "Getting uptime check list to find check by name: $url"
        Try {
            $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json" -Credential $credential -Headers $headers
        } Catch {
            Write-Host "Error occured when getting uptime check list in Pingdom: " + $_.Exception.Message
        }

        $checkFiltered = $response.checks | Where-Object { $_.name -eq $pingdomCheckName }
        If ($checkFiltered -eq $null) {
            Write-Warning "Check with name $pingdomCheckName not found!"
            Exit
        }

        $pingdomCheckId = $checkFiltered.id
    }

    If ([string]::IsNullOrEmpty($pingdomCheckId)) {
        Write-Warning "Check with name $pingdomCheckName was not found!"
        Exit
    }

    # Pause or resume check

    $url += "/$pingdomCheckId"

    $apiParameters = @{}
    $apiParameters.Add("host", $pingdomCheckTarget)
    $apiParameters.Add("contactids", $pingdomCheckContactIds)
    $apiParameters.Add("integrationids", $pingdomCheckIntegrationIds)
    If ($pingdomCheckPaused -eq "True") {
        $apiParameters.Add("paused", "true")
    } Else {
        $apiParameters.Add("paused", "false")
    }
    If ($pingdomCheckIntervalMinutes -ne $null) {
        $apiParameters.Add("resolution", $pingdomCheckIntervalMinutes)
    }
    If ($pingdomCheckSendNotificationWhenDown -ne $null) {
        $apiParameters.Add("sendnotificationwhendown", $pingdomCheckSendNotificationWhenDown)
    }
    If ($pingdomCheckNotifyAgainEvery -ne $null) {
        $apiParameters.Add("notifyagainevery", $pingdomCheckNotifyAgainEvery)
    }
    If ($pingdomCheckNotifyWhenBackUp -ne $null) {
        $apiParameters.Add("notifywhenbackup", $pingdomCheckNotifyWhenBackUp.ToLower())
    }
    If ($pingdomCheckTags -ne $null) {
        $apiParameters.Add("tags", $pingdomCheckTags)
    }
    If ($pingdomCheckHttpUrl -ne $null) {
        $apiParameters.Add("url", $pingdomCheckHttpUrl)
    }
    If ($pingdomCheckHttpEncryptionEnabled -ne $null) {
        $apiParameters.Add("encryption", $pingdomCheckHttpEncryptionEnabled.ToLower())
    }
    If ($pingdomCheckHttpTargetPort -ne $null) {
        $apiParameters.Add("port", $pingdomCheckHttpTargetPort)
    }
    If ($pingdomCheckAuth -ne $null) {
        $apiParameters.Add("auth", $pingdomCheckAuth)
    }
    If (-Not [string]::IsNullOrEmpty($pingdomCheckShouldContain)) {
        $apiParameters.Add("shouldcontain", $pingdomCheckShouldContain)
    }
    If (-Not [string]::IsNullOrEmpty($pingdomCheckShouldNotContain)) {
        $apiParameters.Add("shouldnotcontain", $pingdomCheckShouldNotContain)
    }
    If ($pingdomCheckPostData -ne $null) {
        $apiParameters.Add("postdata", $pingdomCheckPostData)
    }

    If ($apiParameters.Count -gt 0) {
        $queryString = ""
        $apiParameters.Keys | ForEach-Object { 
            $queryString += ($_ + "=" + [Web.HttpUtility]::UrlEncode($apiParameters.Item($_)) + "&")  
        }
        $queryString = $queryString.Substring(0, $queryString.Length - 1)
        $url += "?$queryString"
    }

    Write-Host "Modifying uptime check: $url"
    Try {
        $response = Invoke-RestMethod -Uri $url -Method Put -ContentType "application/json" -Credential $credential -Headers $headers
        Write-Host $response.message
    } Catch {
        $errMessage = "Error occured when adding uptime check in Pingdom: " + $_.Exception + "`n"
        $errMessage += "Response: " + $_
        If($throwErrorWhenFailed -eq $true) {
            Write-Error $errMessage
        }
        Else {
            Write-Warning $errMessage
        }
    }

    Write-Host "End PingdomModifyUptimeCheck"
}