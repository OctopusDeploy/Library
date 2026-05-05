[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Helper functions
function Retry-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,
 
        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 5,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$Delay = 100
    )

    Begin {
        $count = 0
    }

    Process {
    	$ex=$null
        do {
            $count++
            
            try {
                Write-Verbose "Attempt $count of $Maximum"
                $ScriptBlock.Invoke()
                return
            } catch {
                $ex = $_
                Write-Warning "Error occurred executing command (on attempt $count of $Maximum): $($ex.Exception.Message)"
                Start-Sleep -Milliseconds $Delay
            }
        } while ($count -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw "Execution failed (after $count attempts): $($ex.Exception.Message)"
    }
}
# End Helper functions
[int]$timeoutSec = $null
[int]$maximum = 1
[int]$delay = 100

if(-not [int]::TryParse($OctopusParameters['Timeout'], [ref]$timeoutSec)) { $timeoutSec = 60 }


If ($OctopusParameters["TeamsPostMessage.RetryPosting"] -eq $True) {
	if(-not [int]::TryParse($OctopusParameters['RetryCount'], [ref]$maximum)) { $maximum = 1 }
	if(-not [int]::TryParse($OctopusParameters['RetryDelay'], [ref]$delay)) { $delay = 100 }
	
    Write-Verbose "Setting maximum retries to $maximum using a $delay ms delay"
}

$payload = @{
    title = $OctopusParameters['Title']
    text = $OctopusParameters['Body'];
    themeColor = $OctopusParameters['Color'];
}

Retry-Command -Maximum $maximum -Delay $delay -ScriptBlock {
	# Declare variable for parameters
    $invokeParameters = @{}
    $invokeParameters.Add("Method", "POST")
    $invokeParameters.Add("Uri", $OctopusParameters['HookUrl'])
    $invokeParameters.Add("Body", ($payload | ConvertTo-Json -Depth 4))
    $invokeParameters.Add("ContentType", "application/json; charset=utf-8")
    $invokeParameters.Add("TimeoutSec", $timeoutSec)
    
    # Check for UseBasicParsing
    if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey("UseBasicParsing"))
    {
    	# Add the basic parsing argument
        $invokeParameters.Add("UseBasicParsing", $true)
    }

	$Response = Invoke-RestMethod @invokeParameters
    Write-Verbose "Response: $Response"
}