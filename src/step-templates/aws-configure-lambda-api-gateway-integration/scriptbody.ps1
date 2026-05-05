$ApiGatewayName = $OctopusParameters["AWS.Api.Gateway.Name"]
$ApiRouteKey = $OctopusParameters["AWS.Api.Gateway.Route.Key"]
$ApiLambdaUri = $OctopusParameters["AWS.Api.Gateway.Lambda.Arn"]
$ApiPayloadFormatVersion = $OctopusParameters["AWS.Api.Gateway.Integration.PayloadFormatVersion"]
$ApiConnection = $OctopusParameters["AWS.Api.Gateway.Integration.Connection"]
$ApiIntegrationMethod = $OctopusParameters["AWS.Api.Gateway.Integration.HttpMethod"]
$ApiLambdaAlias = $OctopusParameters["AWS.Api.Gateway.Lambda.Alias"]
$ApiRegion = $OctopusParameters["AWS.Api.Gateway.Region"]

$stepName = $OctopusParameters["Octopus.Step.Name"]

if ([string]::IsNullOrWhiteSpace($ApiGatewayName))
{
	Write-Error "The parameter Gateway Name is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($ApiRouteKey))
{
	Write-Error "The parameter Route Key is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($ApiLambdaUri))
{
	Write-Error "The parameter Lambda ARN is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($ApiPayloadFormatVersion))
{
	Write-Error "The parameter Payload Format Version is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($ApiIntegrationMethod))
{
	Write-Error "The parameter Http Method is required."
    Exit 1
}

Write-Host "Gateway Name: $ApiGatewayName"
Write-Host "Route Key: $ApiRouteKey"
Write-Host "Lambda ARN: $ApiLambdaUri"
Write-Host "Lambda Alias: $ApiLambdaAlias"
Write-Host "Payload Format Version: $ApiPayloadFormatVersion"
Write-Host "VPC Connection: $ApiConnection"
Write-host "API Region: $apiRegion"

if ([string]::IsNullOrWhiteSpace($apiLambdaAlias) -eq $false)
{
	Write-Host "Alias specified, adding it to the Lambda ARN"
	$apiLambdaIntegrationArn = "$($apiLambdaUri):$($apiLambdaAlias)"
}
else
{
	Write-Host "No alias specified, going directly to the lambda function"
	$apiLambdaIntegrationArn = $apiLambdaUri
}

$apiQueryOutput = aws apigatewayv2 get-apis --no-paginate
$apiQueryOutput = ($apiQueryOutput | ConvertFrom-JSON)

$apiList = @($apiQueryOutput.Items)
$apiGatewayToUpdate = $null
foreach ($api in $apiList)
{
	if ($api.Name.ToLower().Trim() -eq $apiGatewayName.ToLower().Trim())
    {
    	Write-Highlight "Found the gateway $apiGatewayName"
    	$apiGatewayToUpdate = $api
        break
    }
}

if ($null -eq $apiGatewayToUpdate)
{
	Write-Error "Unable to find the gateway with the name $apiGatewayName"
    exit 1
}

Write-Host $apiGatewayToUpdate

$apiId = $apiGatewayToUpdate.ApiId
Write-Host "The id of the api gateway is $apiId"

$apiConnectionType = "INTERNET"
if ([string]::IsNullOrWhiteSpace($ApiConnection) -eq $false)
{
	$apiConnectionType = "VPC_LINK"
    $existingVPCLinks = aws apigatewayv2 get-vpc-links --no-paginate
    $existingVPCLinks = ($existingVPCLinks | ConvertFrom-JSON)
    
    $existingVPCLinkList = @($existingVPCLinks.Items)
    foreach ($vpc in $existingVPCLinkList)
    {
    	if ($vpc.Name.ToLower().Trim() -eq $ApiConnection.ToLower().Trim())
        {
        	Write-Host "The name $($vpc.Name) matches $apiConnection"
        	$apiConnectionId = $vpc.VpcLinkId
            break
        }
        elseif ($vpc.VpcLinkId.ToLower().Trim() -eq $apiConnection.ToLower().Trim())
        {
        	Write-Host "The vpc link id $($vpc.VpcLinkId) matches $apiConnection"
        	$apiConnectionId = $vpc.VpcLinkId
            break
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($apiConnectionId) -eq $true)
    {
    	Write-Error "The VPC Connection $apiConnection could not be found.  Please check the name or ID and try again.  Please note: names can be updated, if you are matching by name double check nothing has changed."
        exit 1
    }    
}

$apiIntegrations = aws apigatewayv2 get-integrations --api-id "$apiId" --no-paginate
$apiIntegrations = ($apiIntegrations | ConvertFrom-JSON)

$integrationList = @($apiIntegrations.Items)
$integrationToUpdate = $null
foreach ($integration in $integrationList)
{
	if ($integration.IntegrationUri -eq $apiLambdaIntegrationArn -and $integration.ConnectionType -eq $apiConnectionType -and $integration.IntegrationType -eq "AWS_PROXY" -and $integration.PayloadFormatVersion -eq $ApiPayloadFormatVersion)
    {
    	Write-Highlight "Found the existing integration $($integration.Id)"
    	$integrationToUpdate = $integration
        break
    }
}

if ($null -ne $integrationToUpdate)
{
	Write-Highlight "Updating existing integration"
}
else
{
	Write-Highlight "Creating new integration"
    if ($apiConnectionType -eq "INTERNET")
    {
    	Write-Host "Command line: aws apigatewayv2 create-integration --api-id ""$apiId"" --connection-type ""$apiConnectionType"" --integration-method ""$ApiIntegrationMethod"" --integration-type ""AWS_PROXY"" --integration-uri ""$apiLambdaIntegrationArn"" --payload-format-version ""$ApiPayloadFormatVersion"" "
    	$integrationToUpdate = aws apigatewayv2 create-integration --api-id "$apiId" --connection-type "$apiConnectionType" --integration-method "$ApiIntegrationMethod" --integration-type "AWS_PROXY" --integration-uri "$apiLambdaIntegrationArn" --payload-format-version "$ApiPayloadFormatVersion"
    }
    else
    {
    	Write-Host "Command line: aws apigatewayv2 create-integration --api-id ""$apiId"" --connection-type ""$apiConnectionType"" --connection-id ""$ApiConnectionId"" --integration-method ""$ApiIntegrationMethod"" --integration-type ""AWS_PROXY"" --integration-uri ""$apiLambdaIntegrationArn"" --payload-format-version ""$ApiPayloadFormatVersion"" "
    	$integrationToUpdate = aws apigatewayv2 create-integration --api-id "$apiId" --connection-type "$apiConnectionType" --connection-id "$ApiConnectionId" --integration-method "$ApiIntegrationMethod" --integration-type "AWS_PROXY" --integration-uri "$apiLambdaIntegrationArn" --payload-format-version "$ApiPayloadFormatVersion"    
    }
    
    $integrationToUpdate = ($integrationToUpdate | ConvertFrom-JSON)
}

If ($null -eq $integrationToUpdate)
{
	Write-Error "There was an error finding or creating the integration."
    Exit 1
}

Write-Host "$integrationToUpdate"

Write-Host "Command line: aws apigatewayv2 update-integration --api-id ""$apiId"" --integration-id ""$($integrationToUpdate.IntegrationId)"" --integration-method ""$ApiIntegrationMethod"" "
$updateResult = aws apigatewayv2 update-integration --api-id "$apiId" --integration-id "$($integrationToUpdate.IntegrationId)" --integration-method "$ApiIntegrationMethod"

Write-Host "Command line: aws apigatewayv2 get-routes --api-id ""$apiId"" --no-paginate"
$apiRoutes = aws apigatewayv2 get-routes --api-id "$apiId" --no-paginate
$apiRoutes = ($apiRoutes | ConvertFrom-JSON)

$routeList = @($apiRoutes.Items)
$routeToUpdate = $null
$routePath = "$ApiIntegrationMethod $ApiRouteKey"
$routeTarget = "integrations/$($integrationToUpdate.IntegrationId)"
foreach ($route in $routeList)
{
	Write-Host "Comparing $($route.RouteKey) with $routePath and $($route.Target) with $routeTarget"
	if ($route.RouteKey -eq $routePath -and $route.Target -eq $routeTarget)
    {
    	Write-Highlight "Found the existing path $($route.RouteId)"
    	$routeToUpdate = $route
        break
    }
}

if ($null -eq $routeToUpdate)
{
	Write-Highlight "The route with the path $routePath pointing to integration $($integrationToUpdate.IntegrationId) does not exist.  Creating that one now."
    $routeResult = aws apigatewayv2 create-route --api-id "$apiId" --route-key "$routePath" --target "$routeTarget"
}
else
{
	Write-Highlight "The route with the path $routePath pointing to integration $($integrationToUpdate.IntegrationId) already exists.  Leaving that alone."   
}

$accountInfo = aws sts get-caller-identity
$accountInfo = ($accountInfo | ConvertFrom-JSON)

if ($apiRoute -notcontains "*default")
{
	$routeKeyToUse = $apiRouteKey
    $statementIdToUse = "$($ApiGatewayName)$($apiRouteKey.Replace("/", "-"))"
}
else
{
	$routeKeyToUse = ""
    $statementIdToUse = "$ApiGatewayName"
}
$sourceArn = "arn:aws:execute-api:$($apiRegion):$($accountInfo.Account):$($apiId)/*/*$routeKeyToUse"

Write-Host "Source ARN: $sourceArn"
$hasExistingPolicy = $false
$deleteExistingPolicy = $false

try
{
	Write-Host "Getting existing policies"
	$existingPolicy = aws lambda get-policy --function-name "$apiLambdaIntegrationArn" 2> $null
    
    if ($LASTEXITCODE -eq 255 -or $LASTEXITCODE -eq 254)
    {
    	Write-Host "Last exit code was $LASTEXITCODE the policy does not exist"
    	$hasExistingPolicy = $false
    }
    else
    {
    	Write-Host "The policy exists"
    	$hasExistingPolicy = $true
    }
    
    $existingPolicy = ($existingPolicy | ConvertFrom-JSON)
    Write-Host $existingPolicy
    
    $policyObject = ($existingPolicy.Policy | ConvertFrom-JSON)
    
	$statementList = @($policyObject.Statement)
    Write-Host "Statement List $statementList"
    
    foreach ($existingStatement in $statementList)
    {
    	Write-Host $existingStatement
    	Write-Host "Comparing $($existingStatement.Sid) with $statementIdToUse and $($existingStatement.Condition.ArnLike.'AWS:SourceArn') with $sourceArn"
    	if ($existingStatement.Sid -eq "$statementIdToUse" -and $existingStatement.Condition.ArnLike.'AWS:SourceArn' -ne "$sourceArn")
        {
        	Write-Host "The policy exists but it is not pointing to the write source arn, recreating it."
        	$deleteExistingPolicy = $true
        }
    }
}
catch
{
	Write-Host "Error pulling back the policies, this typically means the policy does not exist"
	$hasExistingPolicy = $false
}

if ($hasExistingPolicy -eq $true -and $deleteExistingPolicy -eq $true)
{
	Write-Highlight "Removing the existing policy $statementIdToUse"
    aws lambda remove-permission --function-name "$apiLambdaIntegrationArn" --statement-id "$statementIdToUse"
}

if ($hasExistingPolicy -eq $false -or $deleteExistingPolicy -eq $true)
{
	Write-Highlight "Adding the policy $statementIdToUse"
	aws lambda add-permission --function-name "$apiLambdaIntegrationArn" --statement-id "$statementIdToUse" --action "lambda:InvokeFunction" --principal "apigateway.amazonaws.com" --qualifier "$ApiLambdaAlias" --source-arn "$sourceArn"
}

Write-Highlight "Setting the output variable 'Octopus.Action[$($stepName)].Output.ApiGatewayEndPoint' to $($apiGatewayToUpdate.ApiEndpoint)"
Set-OctopusVariable -name "ApiGatewayEndPoint" -value "$($apiGatewayToUpdate.ApiEndpoint)"

Write-Highlight "Setting the output variable 'Octopus.Action[$($stepName)].Output.ApiGatewayId' to $apiId"
Set-OctopusVariable -name "ApiGatewayId" -value "$apiId"

Write-Highlight "Setting the output variable 'Octopus.Action[$($stepName)].Output.ApiGatewayArn' to $sourceArn"
Set-OctopusVariable -name "ApiGatewayArn" -value "$sourceArn"
