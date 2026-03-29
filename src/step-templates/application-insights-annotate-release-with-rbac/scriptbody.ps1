# Function to decrypt data
function Convert-PasswordToPlainText {
	$base64password = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($OctopusParameters["AppInsights.ApplicationInsightsAccount.Password"]))
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64password))
}

# Function to ensure all Unicode characters in a JSON string are properly escaped
function Convert-UnicodeToEscapeHex {
  param (
    [parameter(Mandatory = $true)][string]$JsonString
  )
  $JsonObject = ConvertFrom-Json -InputObject $JsonString
  foreach ($property in $JsonObject.PSObject.Properties) {
    $name = $property.Name
    $value = $property.Value
    if ($value -is [string]) {
      $value = [regex]::Unescape($value)
      $OutputString = ""
      foreach ($char in $value.ToCharArray()) {
        $dec = [int]$char
        if ($dec -gt 127) {
          $hex = [convert]::ToString($dec, 16)
          $hex = $hex.PadLeft(4, '0')
          $OutputString += "\u$hex"
        }
        else {
          $OutputString += $char
        }
      }
      $JsonObject.$name = $OutputString
    }
  }
  return ConvertTo-Json -InputObject $JsonObject -Compress
}

$applicationName = $OctopusParameters["AppInsights.ApplicationName"]
$resourceGroup = $OctopusParameters["AppInsights.ResourceGroup"]
$releaseName = $OctopusParameters["AppInsights.ReleaseName"]
$properties = $OctopusParameters["AppInsights.ReleaseProperties"]

# Authenticate via Service Principal
$securePassword = Convert-PasswordToPlainText
$azEnv = if($OctopusParameters["AppInsights.ApplicationInsightsAccount.AzureEnvironment"]) { $OctopusParameters["AppInsights.ApplicationInsightsAccount.AzureEnvironment"] } else { "AzureCloud" }

$azEnv = Get-AzEnvironment -Name $azEnv
if (!$azEnv) {
	Write-Error "No Azure environment could be matched given the name $($OctopusParameters["AppInsights.ApplicationInsightsAccount.AzureEnvironment"])"
	exit -2
}

Write-Verbose "Authenticating with Service Principal"

# Force any output generated to be verbose in Octopus logs.
az login --service-principal -u $OctopusParameters["AppInsights.ApplicationInsightsAccount.Client"] -p $securePassword --tenant $OctopusParameters["AppInsights.ApplicationInsightsAccount.TenantId"]

Write-Verbose "Initiating the body of the annotation"

$releaseProperties = $null

if ($properties -ne $null)
{
    $releaseProperties = ConvertFrom-StringData -StringData $properties
}

$annotation = @{
    Id = [GUID]::NewGuid();
    AnnotationName = $releaseName;
    EventTime = (Get-Date).ToUniversalTime().GetDateTimeFormats("s")[0];
    Category = "Deployment"; #Application Insights only displays annotations from the "Deployment" Category
    Properties = ConvertTo-Json $releaseProperties -Compress
}

$annotation = ConvertTo-Json $annotation -Compress
$annotation = Convert-UnicodeToEscapeHex -JsonString $annotation  

$body = $annotation -replace '(\\+)"', '$1$1"' -replace "`"", "`"`""

Write-Verbose "Send the annotation to Application Insights"

az rest --method put --uri "/subscriptions/$($OctopusParameters["AppInsights.ApplicationInsightsAccount.SubscriptionNumber"])/resourceGroups/$($resourceGroup)/providers/microsoft.insights/components/$($applicationName)/Annotations?api-version=2015-05-01" --body "$($body) "