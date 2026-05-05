$username = $OctopusParameters['Username']
$apiKey = $OctopusParameters['ApiKey']
$loadbalanderId = $OctopusParameters['LoadBalancerID']
$newNodeCondition = $OctopusParameters['NewCondition']
$ipAddress = $OctopusParameters['NodeIpAddress']

if ($newNodeCondition -ne "ENABLED" -and $newNodeCondition -ne "DISABLED" -and $newNodeCondition -ne "DRAINING")
{
    throw "Condition must be one of 'ENABLED', 'DISABLED' or 'DRAINING'"
}

# Get token and manipulation URL

$tokensUri = "https://lon.identity.api.rackspacecloud.com/v2.0/tokens"
$tokensBody = @"
{
    "auth":
    {
       "RAX-KSKEY:apiKeyCredentials":
       {  
          "username": "$username",  
          "apiKey": "$apiKey"
       }
    }  
}
"@

Write-Host "Sending request $tokensBody to $tokensUri"

$tokensResponse = Invoke-WebRequest -Uri $tokensUri -Method Post -Body $tokensBody -ContentType "application/json" -UseBasicParsing

if ($tokensResponse.StatusCode -ne 200)
{
    throw "Authorisation failed"
}

$tokensObj = ConvertFrom-Json -InputObject $tokensResponse.Content

$loadBalancerDetails = $tokensObj.access.serviceCatalog | Where {$_.name -eq "cloudLoadBalancers"}
$endpoints = $loadBalancerDetails.endpoints | Select -First 1
$loadbalancerUrl = $endpoints.publicURL
$token = $tokensObj.access.token.id

# Update node

$header = @{}
$header.Add("X-Auth-Token", $token)
$nodesUrl = "$loadbalancerUrl/loadbalancers/$loadbalancerId/nodes"

Write-Host "Getting node details from $nodesUrl"

$nodesResponse = Invoke-WebRequest -Uri $nodesUrl -Method Get -Headers $header -ContentType "application/json" -UseBasicParsing

if ($nodesResponse.StatusCode -ne 200)
{
    throw "Getting load balancer details failed"
}

$nodesObj = ConvertFrom-Json -InputObject $nodesResponse.Content
$node = $nodesObj.nodes | Where {$_.address -eq $ipAddress}
$nodeId = $node.id

$updateBody = @"
{
    "node": {
        "condition" : "$newNodeCondition"
    }
}
"@
$updateUrl = "$loadbalancerUrl/loadbalancers/$loadbalancerId/nodes/$nodeId"

Write-Host "Updating node $nodeId to $newNodeCondition"
Write-Host "$updateBody"
Write-Host "$updateUrl"

$updateResponse = Invoke-WebRequest -Uri $updateUrl -Body $updateBody -Method Put -Headers $header -ContentType "application/json" -UseBasicParsing

if ($updateResponse.StatusCode -ne 202)
{
    throw "Updating load balancer failed"
}