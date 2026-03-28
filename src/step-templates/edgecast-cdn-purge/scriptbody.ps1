function Clear-EdgeCastCache
{
    [CmdletBinding()]
    Param
    (
        # CDN Account number, can be found in MCC
        [Parameter(Mandatory=$true)]
        $AccountNumber,

        # API Token
        [Parameter(Mandatory=$true)]
        [string]$ApiToken,

         # A string that indicates the CDN or edge CNAME URL for the asset or the location that will be purged from our edge servers. Make sure to include the proper protocol (i.e., http:// or rtmp://).
        [Parameter(Mandatory=$true)]
        [string]
        $MediaPath,

        #An integer that indicates the service for which an asset will be purged. It should be replaced with the ID associated with the desired service., default is 3. HTTP Large
        [ValidateSet(2,3,8,14)]
        [int]
        $MediaType=3
    )

    Begin
    {
        $uri = "https://api.edgecast.com/v2/mcc/customers/$AccountNumber/edge/purge"

        $headers = @{
            'Authorization' = "tok:" + $ApiToken
            'Accept' = 'Application/JSON'
            'Content-Type' = 'Application/JSON'
            }
        $RequestParameters = @{
            'MediaPath'=$MediaPath
            'MediaType'=$MediaType
        }

        $body = ConvertTo-Json $RequestParameters

    }
    Process
    {
        Write-Verbose "Request body $body"
    	$request = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -Body $body -DisableKeepAlive
        $request

    }
    End
    {
    }
}

Clear-EdgeCastCache -AccountNumber $AccountNumber -ApiToken $ApiToken -MediaPath $MediaPath -MediaType $MediaType -Verbose
