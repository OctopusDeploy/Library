[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$uri = $OctopusParameters['Uri']
$customHostHeader = $OctopusParameters['CustomHostHeader']
$expectedCode = [int] $OctopusParameters['ExpectedCode']
$timeoutSeconds = [int] $OctopusParameters['TimeoutSeconds']
$Username = $OctopusParameters['AuthUsername']
$Password = $OctopusParameters['AuthPassword']
$UseWindowsAuth = [System.Convert]::ToBoolean($OctopusParameters['UseWindowsAuth'])
$ExpectedResponse = $OctopusParameters['ExpectedResponse']
$securityProtocol = $OctopusParameters['SecurityProtocol']

Write-Host "Starting verification request to $uri"
if ($customHostHeader)
{
    Write-Host "Using custom host header $customHostHeader"
}

Write-Host "Expecting response code $expectedCode."
Write-Host "Expecting response: $ExpectedResponse."

if ($securityProtocol)
{
    Write-Host "Using security protocol $securityProtocol"
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::parse([Net.SecurityProtocolType], $securityProtocol) 
}

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$success = $false
do
{
    try
    {
        if ($Username -and $Password -and $UseWindowsAuth)
        {
            Write-Host "Making request to $uri using windows authentication for user $Username"
            $request = [system.Net.WebRequest]::Create($uri)
            $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $(ConvertTo-SecureString -String $Password -AsPlainText -Force)
            $request.Credentials = $Credential 
            
            if ($customHostHeader)
            {
                $request.Host = $customHostHeader
            }

            try
            {
                $response = $request.GetResponse()
            }
            catch [System.Net.WebException]
            {
                Write-Host "Request failed :-( System.Net.WebException"
                Write-Host $_.Exception
                $response = $_.Exception.Response
            }
            
        }
		elseif ($Username -and $Password)
        {
            Write-Host "Making request to $uri using basic authentication for user $Username"
            $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $(ConvertTo-SecureString -String $Password -AsPlainText -Force)
            if ($customHostHeader)
            {
                $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -Credential $Credential -Headers @{"Host" = $customHostHeader} -TimeoutSec $timeoutSeconds
            }
            else 
            {
                $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -Credential $Credential -TimeoutSec $timeoutSeconds
            }
        }
		else
        {
            Write-Host "Making request to $uri using anonymous authentication"
            if ($customHostHeader)
            {
                $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -Headers @{"Host" = $customHostHeader} -TimeoutSec $timeoutSeconds
            }
            else 
            {
                $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -TimeoutSec $timeoutSeconds
            }
        }
        
        $code = $response.StatusCode
        $body = $response.Content;
        Write-Host "Recieved response code: $code"
        Write-Host "Recieved response: $body"

        if($response.StatusCode -eq $expectedCode)
        {
            $success = $true
        }
        if ($success -and $ExpectedResponse)
        {
            $success = ($ExpectedResponse -eq $body)
        }
    }
    catch
    {
        # Anything other than a 200 will throw an exception so
        # we check the exception message which may contain the 
        # actual status code to verify
        
        Write-Host "Request failed :-("
        Write-Host $_.Exception

        if($_.Exception -like "*($expectedCode)*")
        {
            $success = $true
        }
    }

    if(!$success)
    {
        Write-Host "Trying again in 5 seconds..."
        Start-Sleep -s 5
    }
}
while(!$success -and $timer.Elapsed -le (New-TimeSpan -Seconds $timeoutSeconds))

$timer.Stop()

# Verify result

if(!$success)
{
    throw "Verification failed - giving up."
}

Write-Host "Sucesss! Found status code $expectedCode"