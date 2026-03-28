$ErrorActionPreference = 'Stop'

$StepTemplate_BaseUrl = $OctopusParameters['#{if Octopus.Web.ServerUri}Octopus.Web.ServerUri#{else}Octopus.Web.BaseUrl#{/if}'].Trim('/')
if ([string]::IsNullOrWhiteSpace($StepTemplate_ApiKey)) {
    throw "The step parameter 'API Key' was not found. This step requires an API Key to function, please provide one and try again."
}

function Invoke-OctopusApi {
    param(
        [Parameter(Position = 0, Mandatory)]$Uri,
        [ValidateSet("Get", "Put")]$Method = 'Get',
        $Body
    )
    $requestParameters = @{
        Uri = ('{0}/{1}' -f $StepTemplate_BaseUrl, $Uri.TrimStart('/'))
        Method = $Method
        Headers = @{ "X-Octopus-ApiKey" = $StepTemplate_ApiKey }
        UseBasicParsing = $true
    }
    if ($null -ne $Body) { $requestParameters.Add('Body', ($Body | ConvertTo-Json -Depth 10)) }
    Write-Verbose "$($Method.ToUpperInvariant()) $($requestParameters.Uri)"   
    Invoke-WebRequest @requestParameters | % Content | ConvertFrom-Json | Write-Output
}

function Test-SpacesApi {
	Write-Verbose "Checking API compatibility";
	$rootDocument = Invoke-OctopusApi 'api/';
    if($rootDocument.Links -ne $null -and $rootDocument.Links.Spaces -ne $null) {
    	Write-Verbose "Spaces API found"
    	return $true;
    }
    Write-Verbose "Pre-spaces API found"
    return $false;
}

if(Test-SpacesApi) {
	$spaceId = $OctopusParameters['Octopus.Space.Id'];
    if([string]::IsNullOrWhiteSpace($spaceId)) {
        throw "This step needs to be run in a context that provides a value for the 'Octopus.Space.Id' system variable. In this case, we received a blank value, which isn't expected - please reach out to our support team at https://help.octopus.com if you encounter this error.";
    }
	$baseApiUrl = "api/$spaceId" ;
} else {
	$baseApiUrl = "api" ;
}

function Check-Scope {
	param(
    	[Parameter(Position = 0, Mandatory)]
        [string]$ScopeName,
        [Parameter(Position = 1, Mandatory)]
        [AllowEmptyCollection()]
        [array]$ScopeValues,
        [Parameter(Position = 2)]
        [array]$ExistingScopeValue,
        [Parameter(Position = 3)]
        [string]$LookingForScopeValue
    )
    
    if ($LookingForScopeValue) {
     	
    	Write-Host "Checking $ScopeName Scope"
        
        $scopes = Create-Scope $ScopeName $ScopeValues $LookingForScopeValue
        
        if (-not ($ExistingScopeValue -and (Compare-Object $ExistingScopeValue $scopes) -eq $null)) {
        	Write-Host "$ScopeName scope does not match"
        	return $false
        }
        Write-Host "$ScopeName scope matches"
    } else {
    	if ($ExistingScopeValue) {
        	Write-Host "$ScopeName scope does not match"
        	return $false
        }
    }
    
    return $true
}

function Create-Scope {
	param(
    	[Parameter(Position = 0, Mandatory)]
        [string]$ScopeName,
        [Parameter(Position = 1, Mandatory)]
        [array]$ScopeValues,
        [Parameter(Position = 2)]
        [string]$ScopeValue
    )
    
    $scopes = @()
    
    foreach ($scope in $ScopeValue.Split($StepTemplate_ScopeDelimiter)) {
    	if ($ScopeName -eq "TenantTag") {
    		$value = $ScopeValues | Where { $_.Id -eq $scope } | Select -First 1
    	}
        else {
    		$value = $ScopeValues | Where { $_.Name -eq $scope } | Select -First 1
    	}
    	$scopes += $value.Id
    }
    
    return $scopes
}

$outputVariableKey = "Octopus.Action[${StepTemplate_DeploymentStep}].Output.${StepTemplate_VariableName}"
if (!$OctopusParameters.ContainsKey($outputVariableKey)) {
    throw "Variable '$StepTemplate_VariableName' has not been output from '$StepTemplate_DeploymentStep'"
}
$isSensitive = [System.Convert]::ToBoolean($StepTemplate_IsSensitive)
$variableType = if ($isSensitive) { "Sensitive" } else { "String" }

$variableValue = $OctopusParameters[$outputVariableKey]
Write-Host "Name: $StepTemplate_VariableName"
Write-Host "Type: $variableType"
Write-Host "Value: $(if ($isSensitive) { "********" } else { $variableValue })"
Write-Host ' '

Write-Host "Retrieving $StepTemplate_VariableSetType variable set..."
if ($StepTemplate_VariableSetType -eq 'project') {
    $variableSet = Invoke-OctopusApi "$baseApiUrl/projects/all" | ? Name -eq $StepTemplate_VariableSetName | % { Invoke-OctopusApi $_.Links.Variables }
}
if ($StepTemplate_VariableSetType -eq 'library') {
    $variableSet = Invoke-OctopusApi "$baseApiUrl/libraryvariablesets/all?ContentType=Variables" | ? Name -eq $StepTemplate_VariableSetName | % { Invoke-OctopusApi $_.Links.Variables }
}
if ($null -eq $variableSet) {
    throw "Unable to find $StepTemplate_VariableSetType variable set '$StepTemplate_VariableSetName'"
}

$variableExists = $false

$variableSet.Variables | ? Name -eq $StepTemplate_TargetName | % {
	if (-not (Check-Scope 'Environment' $variableSet.ScopeValues.Environments $_.Scope.Environment $StepTemplate_EnvironmentScope)) {
    	return
    }

	if (-not (Check-Scope 'Machine' $variableSet.ScopeValues.Machines $_.Scope.Machine $StepTemplate_MachineScope)) {
    	return
    }
    
    if (-not (Check-Scope 'Role' $variableSet.ScopeValues.Roles $_.Scope.Role $StepTemplate_RoleScope)) {
    	return
    }
    
    if (-not (Check-Scope 'Action' $variableSet.ScopeValues.Actions $_.Scope.Action $StepTemplate_ActionScope)) {
    	return
    }
    
    if (-not (Check-Scope 'Channel' $variableSet.ScopeValues.Channels $_.Scope.Channel $StepTemplate_ChannelScope)) {
    	return
    }
    
    if (-not (Check-Scope 'TenantTag' $variableSet.ScopeValues.TenantTags $_.Scope.TenantTag $StepTemplate_TenantTagScope)) {
    	return
    }

    Write-Host "Updating existing variable..."
    Write-Host "Existing value:"
	Write-Host "$(if ($isSensitive) { "********" } else { $_.Value })"
    $_.Value = $variableValue
    $_.Type = $variableType
    $_.IsSensitive = $isSensitive
    $variableExists = $true
}

if (!$variableExists) {
    Write-Host "Creating new variable..."
    
    $variable = @{
        Name = $StepTemplate_TargetName
        Value = $variableValue
        Type = $variableType
        IsSensitive = $isSensitive
        Scope = @{}
    }
    
    if ($StepTemplate_EnvironmentScope) {
    	$variable.Scope['Environment'] = (Create-Scope 'Environment' $variableSet.ScopeValues.Environments $StepTemplate_EnvironmentScope)
    }
    if ($StepTemplate_RoleScope) {
    	$variable.Scope['Role'] = (Create-Scope 'Role' $variableSet.ScopeValues.Roles $StepTemplate_RoleScope)
    }
    if ($StepTemplate_MachineScope) {
    	$variable.Scope['Machine'] = (Create-Scope 'Machine' $variableSet.ScopeValues.Machines $StepTemplate_MachineScope)
    }
    if ($StepTemplate_ActionScope) {
    	$variable.Scope['Action'] = (Create-Scope 'Action' $variableSet.ScopeValues.Actions $StepTemplate_ActionScope)
    }
    if ($StepTemplate_ChannelScope) {
    	$variable.Scope['Channel'] = (Create-Scope 'Channel' $variableSet.ScopeValues.Channels $StepTemplate_ChannelScope)
    }
    if ($StepTemplate_TenantTagScope) {
        $variable.Scope['TenantTag'] = (Create-Scope 'TenantTag' $variableSet.ScopeValues.TenantTags $StepTemplate_TenantTagScope)
    }
    
    $variableSet.Variables += $variable
}

Write-Host "Saving updated variable set..."
Invoke-OctopusApi $variableSet.Links.Self -Method Put -Body $variableSet | Out-Null
