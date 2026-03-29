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

        throw "Execution failed (after $count attempts): $($ex.Exception.Message)"
    }
}
# End Helper functions

[int]$timeoutSec = $null
[int]$maximum = 1
[int]$delay = 100

if(-not [int]::TryParse($OctopusParameters['PowerAutomatePostAdaptiveCard.Timeout'], [ref]$timeoutSec)) { $timeoutSec = 60 }

if ($OctopusParameters["AutomatePostMessage.RetryPosting"] -eq $True) {
	if(-not [int]::TryParse($OctopusParameters['PowerAutomatePostAdaptiveCard.RetryCount'], [ref]$maximum)) { $maximum = 1 }
	if(-not [int]::TryParse($OctopusParameters['PowerAutomatePostAdaptiveCard.RetryDelay'], [ref]$delay)) { $delay = 100 }
	
    Write-Verbose "Setting maximum retries to $maximum using a $delay ms delay"
}

# Create the payload for Power Automate
$payload = @{
    type        = "message"  # Fixed value for message type
    attachments = @(
        @{
            contentType = "application/vnd.microsoft.card.adaptive"
            content = @{
                type = "AdaptiveCard"
                body = @(
                    @{
                        type = "TextBlock"
                        text = $OctopusParameters['PowerAutomatePostAdaptiveCard.Title']
                        weight = "bolder"
                        size = "medium"
                        color= $OctopusParameters['PowerAutomatePostAdaptiveCard.TitleColor']
                    },
                    @{
                        type = "TextBlock"
                        text = $OctopusParameters['PowerAutomatePostAdaptiveCard.Body']
                        wrap = $true
                        color= $OctopusParameters['PowerAutomatePostAdaptiveCard.BodyColor']
                    }
                )
                actions = @(
                    @{
                        type  = "Action.OpenUrl"
                        title = $OctopusParameters['PowerAutomatePostAdaptiveCard.ButtonTitle']
                        url   = $OctopusParameters['PowerAutomatePostAdaptiveCard.ButtonUrl']
                    }
                )
                "`$schema" = "http://adaptivecards.io/schemas/adaptive-card.json"
                version = "1.0"
            }
        }
    )
}

Retry-Command -Maximum $maximum -Delay $delay -ScriptBlock {
    #Write-Output ($payload | ConvertTo-Json -Depth 6)
  
    # Prepare parameters for the POST request
    $invokeParameters = @{
        Method      = "POST"
        Uri         = $OctopusParameters['PowerAutomatePostAdaptiveCard.HookUrl']
        Body        = ($payload | ConvertTo-Json -Depth 6 -Compress)
        ContentType = "application/json; charset=utf-8"
        TimeoutSec  = $timeoutSec
    }

    # Check for UseBasicParsing (needed for some environments)
    if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey("PowerAutomatePostAdaptiveCard.UseBasicParsing")) {
        $invokeParameters.Add("UseBasicParsing", $true)
    }

    # Send the request to the Power Automate webhook
    $Response = Invoke-RestMethod @invokeParameters
    Write-Verbose "Response: $Response"
}
