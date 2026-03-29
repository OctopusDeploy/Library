$functionName = $OctopusParameters["AWS.Lambda.Function.Name"]
$functionAliasName = $OctopusParameters["AWS.Lambda.Alias.Name"]
$functionAliasPercent = $OctopusParameters["AWS.Lambda.Alias.Percent"]
$functionVersion = $OctopusParameters["AWS.Lambda.Alias.FunctionVersion"]

if ([string]::IsNullOrWhiteSpace($functionName))
{
	Write-Error "The parameter Function Name is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($functionAliasName))
{
	Write-Error "The parameter Alias Name is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($functionVersion))
{
	Write-Error "The parameter Function Version is required."
    Exit 1
}

if ([string]::IsNullOrWhiteSpace($functionAliasPercent))
{
	Write-Error "The parameter Alias Percent is required."
    Exit 1
}

$newVersionPercent = [int]$functionAliasPercent
    
if ($newVersionPercent -le 0 -or $newVersionPercent -gt 100)
{
    Write-Error "The parameter Alias Percent must be between 1 and 100."
    exit 1
}

Write-Host "Function Name: $functionName"
Write-Host "Function Version: $functionVersion"
Write-Host "Function Alias Name: $functionAliasName"
Write-Host "Function Alias Percent: $functionAliasPercent"

$versionToUpdateTo = $functionVersion
if ($functionVersion.ToLower().Trim() -eq "latest" -or $functionVersion.ToLower().Trim() -eq "previous")
{
	Write-Highlight "The function version specified is $functionVersion, attempting to find the specific version number."
    $versionOutput = aws lambda list-versions-by-function --function-name "$functionName" --no-paginate
    $versionOutput = $versionOutput | ConvertFrom-JSON
    $versionList = @($versionOutput.Versions)
    
    if ($functionVersion.ToLower().Trim() -eq "previous" -and $versionList.Count -gt 2)
    {
    	$versionArrayIndex = $versionList.Count - 2
    }
    else
    {
    	$versionArrayIndex = $versionList.Count - 1
    }
    
    $versionToUpdateTo = $versionList[$versionArrayIndex].Version
    Write-Highlight "The alias will update to version $versionToUpdateTo"         
}

try
{
  Write-Host "Publish set to yes with a function alias specified.  Attempting to find existing alias."
  $aliasInformation = aws lambda get-alias --function-name "$functionName" --name "$functionAliasName" 2> $null

  Write-Host "The exit code from the alias lookup was $LASTEXITCODE"
  if ($LASTEXITCODE -eq 255 -or $LASTEXITCODE -eq 254)
  {
  	  Write-Highlight "The function's alias $functionAliasName does not exist."
      Write-Host "If you see an error right here you can safely ignore that."
	  $aliasInformation = $null
  }   
  else
  {
	  Write-Highlight "The function's alias $functionAliasName already exists."
	  $aliasInformation = $aliasInformation | ConvertFrom-JSON
	  Write-Host $aliasInformation
  }  
}
catch
{
  Write-Host "The alias specified $functionAliasName does not exist for $functionName.  Will create a new alias with that name."
  $aliasInformation = $null
}

if ($null -ne $aliasInformation)
{
  	Write-Host "Comparing the existing alias version $($aliasInformation.FunctionVersion) with the the published version $versionToUpdateTo"
                    
   	if ($aliasInformation.FunctionVersion -ne $versionToUpdateTo)
    {
    	Write-Host "The alias $functionAliasName version $($aliasInformation.FunctionVersion) does not equal the published version $versionToUpdateTo"
            
        if ($newVersionPercent -eq 100)
        {
         	Write-Highlight "The percent for the new version of the function is 100%, updating the alias $functionAliasName to function version $versionToUpdateTo"
           	$newAliasInformation = aws lambda update-alias --function-name "$functionName" --name "$functionAliasName" --function-version "$versionToUpdateTo" --routing-config "AdditionalVersionWeights={}"
        }
        else
        {              	
            $newVersionPercent = $newVersionPercent / [double]100                       
                
            Write-Highlight "Updating the alias $functionAliasName so $functionAliasPercent of all traffic is routed to $versionToUpdateTo"
			  
   	        $newAliasInformation = aws lambda update-alias --function-name "$functionName" --name "$functionAliasName" --routing-config "AdditionalVersionWeights={""$versionToUpdateTo""=$newVersionPercent}"
        }           
    }
    elseif ($newVersionPercent -eq 100)
    {
    	Write-Highlight "The alias $functionAliasName is already pointed to $versionToUpdateTo and the percent sent in is 100, updating the function so all traffic is routed to that version."
        $newAliasInformation = aws lambda update-alias --function-name "$functionName" --name "$functionAliasName" --routing-config "AdditionalVersionWeights={}"
    }
    else
    {
   		Write-Highlight "The alias $functionAliasName is already pointed to $versionToUpdateTo.  Leaving as is."
    }
}
else
{
   	Write-Highlight "Creating the alias $functionAliasName with the version $versionToUpdateTo"
 	$newAliasInformation = aws lambda create-alias --function-name "$functionName" --name "$functionAliasName" --function-version "$versionToUpdateTo"
}

if ($null -ne $newAliasInformation)
{
	Write-Host ($newAliasInformation | ConvertFrom-JSON)
}

Write-Highlight "The alias has finished updating."