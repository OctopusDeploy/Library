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

function Get-OctopusSetting {
    param([Parameter(Position = 0, Mandatory)][string]$Name, [Parameter(Position = 1, Mandatory)]$DefaultValue)
    $formattedName = 'Octopus.Action.{0}' -f $Name
    if ($OctopusParameters.ContainsKey($formattedName)) {
        $value = $OctopusParameters[$formattedName]
        if ($DefaultValue -is [bool]) { return ([System.Convert]::ToBoolean($value)) }
        if ($DefaultValue -is [array] -or $DefaultValue -is [hashtable] -or $DefaultValue -is [pscustomobject]) { return (ConvertFrom-Json -InputObject $value) }
        return $value
    }
    else { return $DefaultValue }
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
$variableSet.Variables | ? Name -eq $StepTemplate_VariableName | % {
    Write-Host "Updating existing variable..."
    Write-Verbose "Existing value: $(if ($isSensitive) { "********" } else { $_.Value })"
    $_.Value = $variableValue
    $_.Type = $variableType
    $_.IsSensitive = $isSensitive
    $_.Scope = Get-OctopusSetting Scope $_.Scope
    $variableExists = $true
}
if (!$variableExists) {
    Write-Host "Creating new variable..."
    $variableSet.Variables += @{
        Name = $StepTemplate_VariableName
        Value = $variableValue
        Type = $variableType
        IsSensitive = $isSensitive
        Scope = (Get-OctopusSetting Scope @{})
    }
}

Write-Host "Saving updated variable set..."
Invoke-OctopusApi $variableSet.Links.Self -Method Put -Body $variableSet | Out-Null