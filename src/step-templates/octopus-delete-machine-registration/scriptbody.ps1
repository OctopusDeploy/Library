[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OctopusAPIKey = $OctopusParameters["DeleteTarget.Octopus.Api.Key"]
$TargetName = $OctopusParameters["DeleteTarget.Target.Name"]
$OctopusUrl = $OctopusParameters["DeleteTarget.Octopus.Base.Url"]
$SpaceId = $OctopusParameters["Octopus.Space.Id"]
$TargetType = $OctopusParameters["DeleteTarget.Target.TargetType"]

Write-Host "Target Name: $TargetName"
Write-Host "Octopus URL: $OctopusUrl"
Write-Host "Space Id: $SpaceId"
Write-Host "Target Type: $TargetType"

$header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$header.Add("X-Octopus-ApiKey", $OctopusAPIKey)

$baseApiUrl = "$OctopusUrl/api"
$baseApiInformation = Invoke-RestMethod $baseApiUrl -Headers $header
if ((Get-Member -InputObject $baseApiInformation.Links -Name "Spaces" -MemberType Properties) -ne $null)
{
	$baseApiUrl = "$baseApiUrl/$SpaceId"
}

$baseTargetUrl = "$baseApiUrl/machines"

if ($TargetType -eq "Worker")
{
	$baseTargetUrl = "$baseApiUrl/workers"
    Write-Host "Worker was selected, switching over to use the URL $baseTargetUrl"
}

$targetListUrl = "$($baseTargetUrl)?skip=0&take=1000&partialName=$TargetName"
Write-Host "Get a list of all machine using the URL $targetListUrl"

$targetList = (Invoke-RestMethod $targetListUrl -Headers $header)

foreach($target in $targetList.Items)
{
    if ($target.Name -eq $TargetName)
    {
        $targetId = $target.Id
        $itemToDeleteEndPoint = "$baseTargetUrl/$targetId"
        try
        {        	
        	Write-Highlight "Deleting the machine $targetId because the name $($target.Name) matches the $TargetName $itemToDeleteEndPoint"
        	$deleteResponse = (Invoke-RestMethod $itemToDeleteEndPoint -Headers $header -Method Delete)
            Write-Highlight "Successfully deleted machine $TargetName"
            Write-Host "Delete Response $deleteResponse"
        }
        catch
        {          	
        	$currentDate = Get-Date -Format "_MMddyyyy_HHmm"
        	$target.Name = "$($target.Name)-old$currentdate"
            $target.IsDisabled = $True
            
            $jsonRequest = $target | ConvertTo-Json
                        
            Write-Highlight "There was an error deleting the machine, renaming it to $($target.name) and disabling it"
          	Write-Host $_
            $machineResponse = Invoke-RestMethod $itemToDeleteEndPoint -Headers $header -Method PUT -Body $jsonRequest
        } 
        
        break
    }
}